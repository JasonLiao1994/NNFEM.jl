if [ ! -d "Adept-2" ]; then
  git clone https://github.com/rjhogan/Adept-2
fi
cd Adept-2
autoreconf -i
./configure  --with-blas=openblas  CXXFLAGS="-g -O3"
make -j
make check
make install
