## public cocoapod, depends on public pods
## pod trunk register florian.nowotny@nacamar.de 'Florian Nowotny' --description='macbook pro'
## session needs to be confirmed by email
pod trunk push YbridPlayerSDK.podspec --allow-warnings --verbose

# ## privte cocoapods, depends on private pods
# pod repo push Private-CocoaPods YbridPlayerSDK.podspec --sources=git@github.com:ybrid/Private-Cocoapods --allow-warnings --verbose 
# ## private cocoapods, depends on public pods
# pod repo push Private-CocoaPods YbridPlayerSDK.podspec --sources='https://github.com/CocoaPods/Specs.git' --allow-warnings --verbose 
