Pod::Spec.new do |s|
	s.name                   = "Syncs"
	s.version                = "1.0.4"
	s.summary                = "A Real-Time web framework, swift library"
	s.homepage               = "https://github.com/manp/syncs-swift"
	s.license                = { :type => "MIT", :file => "LICENSE" }
	s.source                 = { :git => "https://github.com/manp/syncs-swift.git", :tag => "1.0.4" }
	s.authors                = { 'Mostafa Alinaghi-pour' => 'mostafa.alinaghipour@gmail.com' }
	s.ios.deployment_target  = "8.0"
	s.osx.deployment_target  = "10.9"
	s.tvos.deployment_target = "9.0"
	s.source_files           = "Syncs/Classes/**/*","Syncs/Classes/**/*.swift"
	s.dependency 'SwiftWebSocket'
	s.dependency 'SwiftyJSON'
end

