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
# Test player framework on platforms.
#
# Usage: no parameters
# 

scheme=player-sdk-swiftIOSTests
target=player-sdk-swiftIOSTests
testing="-only-testing:$target/DevelopingPlayerTests -only-testing:$target/UseAudioPlayerTests"

dd=./DerivedData
# clean up?
#rm -rfd $dd

logbase="test-"
rm -f "$logbase*.log"

platform=iphonesimulator
device="iPhone 11 Pro"
logfile=$logbase$device.log
echo "testing with $platform on $device"
xcodebuild -workspace player-sdk-swift.xcworkspace -scheme $scheme \
  -destination "name=$device" -sdk $platform \
  test $testing 2>&1 > "$logfile"
result=`cat "$logfile" | grep -e "\*\* TEST"`
echo "$result, see $logfile"
echo "---------------------------------"

## Will fail as long as iOS Simulators with iOS < 14 cannot run AudioEngine
# device="iPhone 6s"
# logfile=$logbase$device.log
# echo "testing with $platform on $device"
# xcodebuild -workspace player-sdk-swift.xcworkspace -scheme $scheme \
#   -destination "platform=iOS Simulator,OS=11.4,name=$device" -sdk $platform \
#   test $testing 2>&1 > "$logfile"
# result=`cat "$logfile" | grep -e "\*\* TEST"`
# echo "$result, see $logfile"
# echo "---------------------------------"

# ## Will fail as long as AVAudioSession is not correctly activated
# platform=iphoneos
# #device="Nacamars iPad Air" # iOS 12
# #device="Nacamar's iPad Mini" # iOS 9
# device="iPhone von Florian" # iOS 14
# echo "testing with $platform on $device"
# logfile=$logbase$device.log
# xcodebuild -workspace player-sdk-swift.xcworkspace -scheme $scheme \
#   -destination "platform=iOS,name=$device" -sdk $platform \
#   test $testing 2>&1 > "$logfile"
# result=`cat "$logfile" | grep -e "\*\* TEST"`
# echo "$result, see $logfile"
# echo "---------------------------------"


# platform=macosx
# scheme=player-sdk-swiftMacTests
# target=player-sdk-swiftMacTests
# testing="-only-testing $target/DevelopingPlayerTests"
# device="My Mac"
# echo "testing with $platform on $device"
# logfile=$logbase$device.log
# xcodebuild -workspace player-sdk-swift.xcworkspace -scheme $scheme \
#   -destination='$device' -sdk $platform \
#   test $testing 2>&1 > "$logfile"
# result=`cat "$logfile" | grep -e "\*\* TEST"`
# echo "$result, see $logfile"
# echo "---------------------------------"

