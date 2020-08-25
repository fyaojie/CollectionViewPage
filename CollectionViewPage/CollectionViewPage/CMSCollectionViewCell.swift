//
//  CMSCollectionViewCell.swift
//  test
//
//  Created by love on 2020/8/19.
//  Copyright © 2020 bonree. All rights reserved.
//

import UIKit

public class CMSCollectionViewCell: UICollectionViewCell {
    
    var model: CMSCycleScrollModel? {
        didSet {
            self.titleLabel.text = model?.title
            self.changeScaleLabel.text = model?.changeScale
            self.subtitleLabel.text = model?.subtitle
        }
    }
    
    fileprivate lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 17)
        label.textColor = UIColor.hex("#333333")
        return label
    }()
    
    fileprivate lazy var changeScaleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.hex("#E12121")
        return label
    }()
    
    fileprivate lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = UIColor.hex("#666666")
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    
        contentView.addSubview(titleLabel)
        contentView.addSubview(changeScaleLabel)
        contentView.addSubview(subtitleLabel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()

        contentView.clipsToBounds = true
        contentView.layer.cornerRadius = 6
        contentView.backgroundColor = .white
        let titleHeight = height(titleLabel)
        let changeScaleHeight = height(changeScaleLabel)
        let subtitleHeight = height(subtitleLabel)
        let titleY = (bounds.height - titleHeight - 5 - changeScaleHeight - 3 - subtitleHeight)/2
        
        titleLabel.frame = CGRect(x: 0, y: titleY, width: bounds.width, height: titleHeight)
        
        changeScaleLabel.frame = CGRect(x: 0, y: titleLabel.frame.maxY + 5, width: bounds.width, height: changeScaleHeight)
        subtitleLabel.frame = CGRect(x: 0, y: changeScaleLabel.frame.maxY + 3, width: bounds.width, height: subtitleHeight)
    }
    
    fileprivate func height(_ label: UILabel) -> CGFloat {
        guard let text = label.text else { return 20 }
        return text.boundingRect(with: CGSize(width: CGFloat(MAXFLOAT), height: CGFloat(MAXFLOAT)), options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font : label.font ?? UIFont.systemFontSize], context: nil).size.height
    }
}

extension UIColor{
  class func hex(_ hexStr:String, alpha:Float = 1) -> UIColor {
    var cStr = hexStr.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).uppercased() as NSString;
    
    if(cStr.length < 6){
        return UIColor.clear;
    }
    
    if(cStr.hasPrefix("0x")) {
        cStr = cStr.substring(from: 2) as NSString
    }
    
    if(cStr.hasPrefix("#")){
        cStr = cStr.substring(from: 1) as NSString
    }
    
    if(cStr.length != 6){
        return UIColor.clear;
    }
    
    let rStr = (cStr as NSString).substring(to: 2)
    let gStr = ((cStr as NSString).substring(from: 2) as NSString).substring(to: 2)
    let bStr = ((cStr as NSString).substring(from: 4) as NSString).substring(to: 2)
    
    var r : UInt64 = 0x0
    var g : UInt64 = 0x0
    var b : UInt64 = 0x0
    
    Scanner.init(string: rStr).scanHexInt64(&r);
    Scanner.init(string: gStr).scanHexInt64(&g);
    Scanner.init(string: bStr).scanHexInt64(&b);
    
    return UIColor.init(red: CGFloat(r)/255.0, green: CGFloat(g)/255.0, blue: CGFloat(b)/255.0, alpha: CGFloat(alpha));
    }
}
