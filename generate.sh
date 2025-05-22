#!/bin/bash

# Generate Packages with proper architecture mapping
dpkg-scanpackages -m debs / > Packages 2>/dev/null

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

# Add hashes (Mac-specific formatting)
echo "MD5Sum:" >> Release
md5 debs/*.deb | sed 's/MD5 (//;s/) = / /' | awk '{print " " $2 " " $3 " ./debs/" $1}' >> Release

echo "SHA1:" >> Release
shasum -a 1 debs/*.deb | sed 's/debs\///' | awk '{print " " $1 " " $2 " ./debs/" $2}' >> Release

echo "SHA256:" >> Release
shasum -a 256 debs/*.deb | sed 's/debs\///' | awk '{print " " $1 " " $2 " ./debs/" $2}' >> Release

# Final size verification
echo "Size: $(wc -c < Packages)" >> Release
