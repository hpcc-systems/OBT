#cd build

#/usr/local/bin/cmake ../$1 -DUSE_LIBXSLT=ON -DXALAN_LIBRARIES= 

/usr/local/bin/cmake ../$1 -DUSE_LIBXSLT=ON -DXALAN_LIBRARIES= -DCLIENTTOOLS_ONLY=ON -DUSE_PYTHON=OFF -DUSE_V8=OFF -DUSE_JNI=OFF -DUSE_RINSIDE=OFF

#make
#make package
