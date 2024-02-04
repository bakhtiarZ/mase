import torch
import pandas as pd
import logging
from tabulate import tabulate
import numpy as np
import itertools
from functools import partial
from .base import SearchStrategyBase

from chop.passes.module.analysis import calculate_avg_bits_module_analysis_pass

logger = logging.getLogger(__name__)

class SearchStrategyBruteForce(SearchStrategyBase):

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
        
        df = pd.DataFrame(rec_metrics).to_csv("search_metrics.csv",index=False)
        key_metrics = df[['software_metrics', 'hardware_metrics']].to_numpy()
        optimalvals = np.ones(key_metrics.shape[0], dtype=bool)
        for i, objective in enumerate(key_metrics):
            optimalvals[i] = np.all(np.any(key_metrics < objective, axis=1))
        return df[optimalvals]
            
