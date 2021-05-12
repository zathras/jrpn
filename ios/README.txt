
NOTE:  I hand-edited Runner.xcodeproj/xcshareddata/xcshemees/Runner.xcscheme,
changing the LaunchAction buildConfiguration from "Debug" to "Release".
This is a workaround to not ponying up a hundred bucks a year to Apple for
a developer account, just for the privelege of giving away software.

https://en.wikipedia.org/wiki/.ipa:  
An unsigned .ipa can be created by copying the folder with the 
extension .app from the Products folder of the application in 
Xcode to a folder called Payload and compressing the latter 
using the command zip -0 -y -r myAppName.ipa Payload/.

But, in that case it would still be x86, and not ARM.
