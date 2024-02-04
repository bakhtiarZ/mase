import torch
import pandas as pd
import logging
from tabulate import tabulate
import numpy as np
import itertools
import time
from functools import partial
from .base import SearchStrategyBase
from mpl_toolkits.mplot3d import Axes3D
import matplotlib.pyplot as plt

from chop.passes.module.analysis import calculate_avg_bits_module_analysis_pass

logger = logging.getLogger(__name__)

class SearchStrategyBruteForce(SearchStrategyBase):

    def plot_pareto(self, df_subset, colour = 'viridis'):
      # Creating a 3D plot
      fig = plt.figure(figsize=(10, 8))
      ax = fig.add_subplot(111, projection='3d')
      # Plotting the points
      sc = ax.scatter(df_subset['accuracy'], 
                      df_subset['memory_density'], 
                      df_subset['average_bitwidth'], 
                      c=df_subset['accuracy'], 
                      cmap='viridis', 
                      s=100)

      ax.set_xlabel('Accuracy')
      ax.set_ylabel('Memory Density')
      ax.set_zlabel('Average Bitwidth')
      plt.title('3D Plot of Accuracy, Memory Density, and Average Bitwidth')
      plt.colorbar(sc, label='Accuracy')
      plt.show()

    def is_dominated(self, row, other, show_loss=False):
      if show_loss:
        return (row['loss'] >= other['loss'] and
              row['accuracy'] <= other['accuracy'] and
              row['average_bitwidth'] >= other['average_bitwidth'] and
              row['memory_density'] >= other['memory_density'] and
              (row['loss'] > other['loss'] or
              row['accuracy'] < other['accuracy'] or
              row['average_bitwidth'] > other['average_bitwidth'] or
              row['memory_density'] > other['memory_density']))
      else:        
        return (row['accuracy'] <= other['accuracy'] and
            row['average_bitwidth'] >= other['average_bitwidth'] and
            row['memory_density'] <= other['memory_density'] and
            (row['accuracy'] < other['accuracy'] or
             row['average_bitwidth'] > other['average_bitwidth'] or
             row['memory_density'] < other['memory_density']))
    
    def find_pareto_front(self, df):
        pareto_front = []
        for index, row in df.iterrows():
            if not any(self.is_dominated(row, other) for _, other in df.iterrows()):
                pareto_front.append(row)

        return pd.DataFrame(pareto_front)

    def _post_init_setup(self) -> None:
        self.sum_scaled_metrics = self.config["setup"]["sum_scaled_metrics"]
        self.metric_names = list(sorted(self.config["metrics"].keys()))
        if not self.sum_scaled_metrics:
            self.directions = [
                self.config["metrics"][k]["direction"] for k in self.metric_names
            ]
        else:
            self.direction = self.config["setup"]["direction"]

    def compute_software_metrics(self, model, sampled_config: dict, is_eval_mode: bool):
        # note that model can be mase_graph or nn.Module
        metrics = {}
        if is_eval_mode:
            with torch.no_grad():
                for runner in self.sw_runner:
                    metrics |= runner(self.data_module, model, sampled_config)
        else:
            for runner in self.sw_runner:
                metrics |= runner(self.data_module, model, sampled_config)
        return metrics
    
    def compute_hardware_metrics(self, model, sampled_config, is_eval_mode: bool):
        metrics = {}
        if is_eval_mode:
            with torch.no_grad():
                for runner in self.hw_runner:
                    metrics |= runner(self.data_module, model, sampled_config)
        else:
            for runner in self.hw_runner:
                metrics |= runner(self.data_module, model, sampled_config)
        return metrics

    def search(self, search_space) -> any :
        starttime = time.time()
        sampled_indexes = {}
        for name, length in search_space.choice_lengths_flattened.items():
            sampled_indexes[name] = range(length)
        #this will have something like 'name1' : [0,1], 'name2': [0,1]
        #need to generate something like 
        # {'name1':0, 'name2':0}, {'name1':1, 'name2':1} ... (all combos)
        combinations = list(itertools.product(*sampled_indexes.values())) #generates the combos
        configs = []
        rec_metrics = []
        for combo in combinations:
            configs.append(dict(zip(sampled_indexes.keys(), combo)))
        #now have a normal search space
        for cfg in configs:
            sampled_config = search_space.flattened_indexes_to_config(cfg)
            is_eval_mode = self.config.get("eval_mode", True)
            model = search_space.rebuild_model(sampled_config, is_eval_mode)
            #collect metrics
            software_metrics = self.compute_software_metrics(
                model, sampled_config, is_eval_mode
            )
            hardware_metrics = self.compute_hardware_metrics(
                model, sampled_config, is_eval_mode
            )
            metrics = software_metrics | hardware_metrics
            scaled_metrics = {}
            for metric_name in self.metric_names:
                scaled_metrics[metric_name] = (
                    self.config["metrics"][metric_name]["scale"] * metrics[metric_name]
                )
            metrics = metrics | scaled_metrics
            rec_metrics.append(metrics)
            self.visualizer.log_metrics(metrics=scaled_metrics)
        
        endtime = time.time() - starttime
        print(f"Searching finished, time taken = {endtime}")
        df = pd.DataFrame(rec_metrics)
        pareto_front = self.find_pareto_front(df)
        df.to_json(self.save_dir / "brute_force.json", orient="index", indent=4)
        pareto_front.to_json(self.save_dir / "pareto_brute_force.json", orient="index", indent=4)
        print(self.save_dir)
        print(f"Pareto front of results from the brute force search\n {pareto_front}")
        # self.plot_pareto(pareto_front)
        return pareto_front
      
    

