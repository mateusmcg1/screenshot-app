#!/bin/bash

# 1. Clean previous files
rm -rf debs/*.deb Packages* dists/

# 2. Copy new .deb file
cp ../ios-screen/packages/*.deb debs/

# 3. Generate Packages file
dpkg-scanpackages -m debs /dev/null > Packages

# 4. Create compressed Packages
gzip -9f Packages -c > Packages.gz
bzip2 -9f Packages -c > Packages.bz2
xz -9f Packages -c > Packages.xz

# 5. Create directory structure and move files
mkdir -p dists/ios/main/binary-iphoneos-arm
mv Packages Packages.gz Packages.bz2 Packages.xz dists/ios/main/binary-iphoneos-arm/

# 6. Create Release file
cat > dists/ios/Release <<EOF
Origin: mateusmcg1
Architectures: iphoneos-arm
Components: main
EOF

# 7. Verify final files
echo "=== Repository Contents ==="
find dists/ -type f -print -exec sh -c 'echo "{}:" && ls -l {}' \;
