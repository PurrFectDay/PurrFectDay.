# Uncomment the next line to define a global platform for your project
# platform :ios, '12.0'

target 'Purrfectday' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Purrfectday
  # Add the Firebase pod for Google Analytics
  pod 'FirebaseAnalytics'

  # For Analytics without IDFA collection capability, use this pod instead
  # pod ‘Firebase/AnalyticsWithoutAdIdSupport’

  # Add the pods for any other Firebase products you want to use in your app
  # For example, to use Firebase Authentication and Cloud Firestore
  pod 'FirebaseAuth'
  pod 'FirebaseFirestore'
  pod 'FirebaseDatabase'

  # For Toast
  pod 'Toast-Swift'

  # For LaunchScreen
  pod 'SwiftyGif'

  # For calendar
  pod 'FSCalendar'

  pod 'SnapKit'

end

 post_install do |installer|
     installer.generated_projects.each do |project|
           project.targets.each do |target|
               target.build_configurations.each do |config|
                   config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
                end
           end
    end
 end
