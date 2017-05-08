#
# Be sure to run `pod lib lint Syncs.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Syncs'
  s.version          = '1.0.0'
  s.summary          = 'A Real-Time web framework, swift library'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Gloup.io works as a middleware to enables real-time, bi-directional communication between web clients and web servers.
* Gloup.io provides four abstraction layer over its real-time functionality for developers.

DESC

  s.homepage         = 'https://github.com/manp/syncs-swift'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'manp' => 'mostafa.alinaghipour@gmail.com' }
  s.source           = { :git => 'https://github.com/manp/syncs-swift.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '9.0'

  s.source_files = 'Syncs/Classes/**/*'
  
  # s.resource_bundles = {
  #   'Syncs' => ['Syncs/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
	s.dependency 'SwiftWebSocket'
	s.dependency 'SwiftyJSON'

end
