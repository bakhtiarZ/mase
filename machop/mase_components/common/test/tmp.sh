# create activation script
mkdir -p $CONDA_PREFIX/etc/conda/activate.d
cat > $CONDA_PREFIX/etc/conda/activate.d/use_system_gcc.sh <<'EOF'
#!/usr/bin/env bash
export CC=/usr/bin/gcc
export CXX=/usr/bin/g++
export CXXFLAGS="-I/usr/include -I/usr/include/x86_64-linux-gnu"
export LDFLAGS="-L/usr/lib/x86_64-linux-gnu -lz"
EOF
chmod +x $CONDA_PREFIX/etc/conda/activate.d/use_system_gcc.sh

# optional cleanup on deactivate
mkdir -p $CONDA_PREFIX/etc/conda/deactivate.d
echo -e '#!/usr/bin/env bash\nunset CC CXX CXXFLAGS LDFLAGS' \
  > $CONDA_PREFIX/etc/conda/deactivate.d/clean_system_gcc.sh
chmod +x $CONDA_PREFIX/etc/conda/deactivate.d/clean_system_gcc.sh

