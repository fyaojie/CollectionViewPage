
Pod::Spec.new do |spec|

  spec.name         = "YJCycleCollectionView"
  spec.version      = "0.0.1"
  spec.summary      = "swift 循环视图"

  spec.description  = "封装了系统的UICollectionView,使用更方便"

  spec.homepage     = "https://github.com/fyaojie"

  # s.license      = "MIT"
  spec.license          = { :type => 'MIT', :file => 'LICENSE' }
  

  spec.author       = { "odreamboy" => "562925462@qq.com" }

  spec.platform     = :ios, "10.0"

  spec.source       = { :git => "https://github.com/fyaojie/CollectionViewPage.git", :tag => spec.version }

  spec.source_files  = "YJCycleCollectionView/*.{swift}"
  spec.swift_version= "5.0"
  

end
