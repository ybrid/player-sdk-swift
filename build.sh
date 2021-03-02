#!/bin/sh

# MIT License

# Copyright (c) 2021 Ybrid®, a Hybrid Dynamic Live Audio Technology

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

#
# Generates the player-sdk-swift.xcframework from player-sdk-swift.xcodeworkspace.
# Usage: no parameters, settings mostly defined in xcode xcodeworkspace
# 

scheme=player-sdk-swift
opts="SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES" 

dd=./DerivedData
archivesPath="$dd/Archives"

# clean up
rm -rfd $dd
mkdir -p "$archivesPath"

# path and name of platform specifically generated frameworks 
generatedPath="Products/Library/Frameworks"
framework=YbridPlayerSDK.framework

# where to keep frameworks
builtPath="$dd/Build/Products" 
mkdir -p "$builtPath" 

# generate platform specific frameworks

platform=iphoneos
echo "building for $platform..."
xcodebuild archive -workspace player-sdk-swift.xcworkspace -scheme $scheme \
    -destination="iOS" -sdk $platform -derivedDataPath $dd \
    -archivePath "$archivesPath/$platform.xcarchive" $opts >> "build-$platform.log"
cp -R "$archivesPath/$platform.xcarchive/$generatedPath" "$builtPath/Archive-$platform"

platform=iphonesimulator
echo "building for $platform...."
xcodebuild archive -workspace player-sdk-swift.xcworkspace -scheme $scheme \
    -destination="iOS Simulator" -sdk $platform -derivedDataPath $dd \
    -archivePath "$archivesPath/$platform.xcarchive" $opts > "build-$platform.log"
cp -R "$archivesPath/$platform.xcarchive/$generatedPath" "$builtPath/Archive-$platform"

# currently broken because opus does not correctly support opus
# platform=maccatalyst
# echo "building for $platform...."
# xcodebuild archive -workspace player-sdk-swift.xcworkspace -scheme $scheme \
#     archs="x86_64h" -destination 'generic/platform=macOS,variant=Mac Catalyst,name=Any Mac' \
#     -derivedDataPath $dd -archivePath "$archivesPath/$platform.xcarchive" $opts > "build-$platform.log"
# cp -R "$archivesPath/$platform.xcarchive/$generatedPath" "$builtPath/Archive-$platform"

# broken when Podfile configured for ios, ok when configured for osx
platform=macosx
scheme=player-sdk-swift_mac
echo "building for $platform..."
xcodebuild archive -workspace player-sdk-swift.xcworkspace -scheme $scheme \
    -destination='My Mac' -sdk $platform -derivedDataPath $dd \
    -archivePath "$archivesPath/$platform.xcarchive" $opts > "build-$platform.log"
cp -R "$archivesPath/$platform.xcarchive/$generatedPath" "$builtPath/Archive-$platform"


# resulting player xcframework
xcFramework=YbridPlayerSDK.xcframework
rm -rfd $xcFramework

products=`ls $builtPath | grep Archive`
echo "generating $xcFramework for \n$products\n..."

cmd="xcodebuild -create-xcframework "
for entry in $products; do
    cmd="$cmd -framework $builtPath/$entry/$framework "
done
cmd="$cmd -output $xcFramework"
#echo $cmd
$cmd

cp LICENSE $xcFramework

echo "please generate $xcFramework.zip including LICENSE file..."
# zip -q -r $xcFramework.zip $xcFramework
# echo "done."
