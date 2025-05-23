#!/bin/bash

# 1. Clean previous files
rm -rf debs/*.deb Packages*

# 2. Build the tweak
cd tweakProject
make
cd ..

# 3. Copy the .deb file to debs directory
cp tweakProject/packages/*.deb debs/

# 4. Generate Packages file
dpkg-scanpackages -m debs /dev/null > Packages

# 5. Create compressed Packages
gzip -9f Packages -c > Packages.gz

# 6. Create Release file
cat > Release <<EOF
Origin: mateusmcg1
Label: Screenshot Monitor
Suite: stable
Version: 1.0
Codename: ios
Architectures: iphoneos-arm
Components: main
Description: Screenshot Monitor Tweak Repository
EOF

# 7. Verify final files
echo "=== Repository Contents ==="
ls -la
