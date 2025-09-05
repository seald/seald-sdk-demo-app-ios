use_frameworks!

platform :ios, '13.0'
project 'SealdSDK demo app ios'

target 'SealdSDK demo app ios_Example' do
  pod 'SealdSdk', '0.10.0-beta.4'
  pod 'JWT', '3.0.0-beta.14'

  # This fixes the build of Base64 (dependency of `JWT`) on certain macs.
  # Should not be necessary in an actual app which uses the SealdSDK,
  # because it would not use the `JWT` library (JWTs should be generated on the back-end).
  post_install do |installer|
    installer.generated_projects.each do |project|
      project.targets.each do |target|
        target.build_configurations.each do |config|
          config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
        end
      end
    end
  end
end
