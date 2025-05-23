#!/bin/bash

# Ensure the .deb file is in the debs folder
cp ../ios-screen/packages/*.deb debs/

# Generate Packages with proper architecture mapping
dpkg-scanpackages -m debs /dev/null > Packages 2>/dev/null

# Create compressed versions
gzip -c9 Packages > Packages.gz
bzip2 -c9 Packages > Packages.bz2
xz -c9 Packages > Packages.xz

# Generate Release file
cat > Release <<RELEASE_EOF
Origin: mateusmcg1
Label: Screenshot App Repo
Suite: stable
Version: 1.0
Codename: ios
Architectures: iphoneos-arm
Components: main
Description: Screenshot Monitor Tweak Repository
RELEASE_EOF

# Add hashes (correct path formatting)
echo "MD5Sum:" >> Release
md5 -q debs/*.deb | awk -v f=$(basename debs/*.deb) -v s=$(stat -f%z debs/*.deb) '{print " " $1, s, "debs/" f}' >> Release

echo "SHA1:" >> Release
shasum debs/*.deb | awk -v f=$(basename debs/*.deb) -v s=$(stat -f%z debs/*.deb) '{print " " $1, s, "debs/" f}' >> Release

echo "SHA256:" >> Release
shasum -a 256 debs/*.deb | awk -v f=$(basename debs/*.deb) -v s=$(stat -f%z debs/*.deb) '{print " " $1, s, "debs/" f}' >> Release

# Final size verification
echo "Size: $(wc -c < Packages)" >> Release
