#
# paper_scanner_ios — iOS implementation of the paper_scanner plugin.
#
Pod::Spec.new do |s|
  s.name             = 'paper_scanner_ios'
  s.version          = '0.1.0'
  s.summary          = 'iOS implementation of paper_scanner (Vision + CoreImage).'
  s.description      = <<-DESC
Document detection via Apple Vision (VNDetectDocumentSegmentationRequest with a
VNDetectRectanglesRequest fallback), perspective crop and filters via CoreImage.
                       DESC
  s.homepage         = 'https://github.com/your-org/paper_scanner'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'paper_scanner contributors' => 'noreply@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'

  # Vision document segmentation is runtime-gated to iOS 15+ in code.
  s.frameworks = 'Vision', 'CoreImage', 'CoreGraphics', 'UIKit'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
