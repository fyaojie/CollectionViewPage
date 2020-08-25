//
//  YJCustomCycleCollectionView.swift
//  CollectionViewPage
//
//  Created by love on 2020/8/25.
//  Copyright © 2020 symbio. All rights reserved.
//

import UIKit

public protocol YJCustomCycleCollectionViewDelegate : NSObjectProtocol {
    func collectionView(_ collectionView: YJCustomCycleCollectionView, numberOfItemsInSection section: Int) -> Int
    func collectionView(_ collectionView: YJCustomCycleCollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
}

public class YJCustomCycleCollectionView: UIView {

    /// 监听点击
    public var didSelectItemBlock : ((_ currentIndex: Int) -> (Void))?
    
    /// 监听滚动的结果 currentIndex 翻页滚动时返回   offset 非翻页滚动时返回偏移量
    public var didScrollItemOperationBlock : ((_ currentIndex: Int?, _ offset: CGPoint?) -> (Void))?
    
    /// 外边距
    public var marginInset : UIEdgeInsets = .zero {
        didSet {
            setNeedsLayout()
            layoutIfNeeded()
            reloadData()
        }
    }
    /// 内边距
    public var paddingInset : UIEdgeInsets = .zero {
        didSet {
            reloadData()
        }
    }
    /// 是否无限循环
    public var isInfiniteLoop : Bool = true {
        didSet {
            fixInfiniteLoopLocation()
            reloadData()
        }
    }
    /// 修正比例，无限循环条件下生效，阈值 0-1， 0 不修正， 1持续修正
    public var fixScale : CGFloat = 0.1
    /// 方向
    public var scrollDirection : UICollectionView.ScrollDirection = .horizontal {
        didSet {
            if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                layout.scrollDirection = scrollDirection
            }
            fixInfiniteLoopLocation()
            reloadData()
        }
    }
    
    /// item 宽高比(竖向 高宽比)，默认1 如果想指定大小，设置为0, 阈值[0,5]
    public var itemSizeScale : CGFloat = 1 {
        didSet {
           reloadData()
        }
    }
    /// 高度不能大于frame - 内边距，否则按照比例自动缩减
    public var itemSize : CGSize = .zero {
        didSet {
           reloadData()
        }
    }
    
    /// 是否按页操作
    public var isPagingEnabled : Bool = true
    
    /// 间距
    public var minimumLineSpacing : CGFloat = 0 {
        didSet {
            reloadData()
        }
    }
    
//    /// 上下间距
//    public var minimumInteritemSpacing : CGFloat = 0 {
//        didSet {
//            reloadData()
//        }
//    }
    
    weak open var delegate: YJCustomCycleCollectionViewDelegate?
    
    open func register(_ cellClass: AnyClass?, forCellWithReuseIdentifier identifier: String) {
        collectionView.register(cellClass, forCellWithReuseIdentifier: identifier)
    }

    open func register(_ nib: UINib?, forCellWithReuseIdentifier identifier: String) {
        collectionView.register(nib, forCellWithReuseIdentifier: identifier)
    }
    
    open func dequeueReusableCell(withReuseIdentifier identifier: String, for indexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath)
    }
    
    open func reloadData() {
        originItemsCount = delegate?.collectionView(self, numberOfItemsInSection: 0) ?? 0
        collectionView.reloadData()
    }
    
    /// 真实大小
    fileprivate var realItemSize : CGSize {
        get {
            let tempScale = min(5, max(0, itemSizeScale))
            
            /// 这里需要考虑横向和竖向的问题
            
            switch scrollDirection {
            case .horizontal:
                let maxSizeHeight = self.frame.height - paddingInset.top - paddingInset.bottom - marginInset.top - marginInset.bottom
                /// 需要指定size
                if tempScale == 0 {
                    /// 该size可用
                    if maxSizeHeight >= itemSize.height {
                        return itemSize
                    }
                    let tempSizeScale = itemSize.width / itemSize.height
                    let newSize = CGSize(width: maxSizeHeight * tempSizeScale, height: maxSizeHeight)
                    return newSize
                }
                
                let newSize = CGSize(width: maxSizeHeight * itemSizeScale, height: maxSizeHeight)
                return newSize
            case .vertical:
                let maxSizeWidth = self.frame.width - paddingInset.left - paddingInset.right - marginInset.left - marginInset.right
                /// 需要指定size
                if tempScale == 0 {
                    /// 该size可用
                    if maxSizeWidth >= itemSize.width {
                        return itemSize
                    }
                    let tempSizeScale = itemSize.width / itemSize.height
                    let newSize = CGSize(width: maxSizeWidth, height: maxSizeWidth * tempSizeScale)
                    return newSize
                }
                
                let newSize = CGSize(width: maxSizeWidth , height: maxSizeWidth * itemSizeScale)
                return newSize
            @unknown default:
                fatalError()
            }
        }
    }
    /// 是否有速度,用于判定何时结束
    fileprivate var rate : Bool = false
    
    /// 真实数量
    fileprivate var totalItemsCount : Int {
        get {
            originItemsCount * (isInfiniteLoop ? 200 : 1)
        }
    }
    
    /// 原始数量
    fileprivate var originItemsCount : Int = 0
    
    fileprivate lazy var flowLayout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = scrollDirection
        return layout
    }()
    
    fileprivate lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: self.bounds, collectionViewLayout: self.flowLayout)
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.scrollsToTop = false
        if #available(iOS 11.0, *) {
            collectionView.contentInsetAdjustmentBehavior = .never
        } else {
            // Fallback on earlier versions
        }
        addSubview(collectionView)
        return collectionView
    }()
    
    public override func layoutSubviews() {
        super.layoutSubviews()

        let x = marginInset.left
        let y = marginInset.top
        let width = bounds.width - marginInset.left - marginInset.right
        let height = bounds.height - marginInset.top - marginInset.bottom
        collectionView.frame = CGRect(x: x, y: y, width: width, height: height)
        
        /// 无限循环模式下调整位置
        if collectionView.contentOffset.x == 0 && totalItemsCount > 0 && isInfiniteLoop {
            let targetIndex : Float = isInfiniteLoop ? Float(totalItemsCount) * 0.5 : 0
            collectionView.scrollToItem(at: IndexPath(item: Int(targetIndex), section: 0), at: UICollectionView.ScrollPosition.left, animated: false)
        }
    }
    
    deinit {
        collectionView.delegate = nil
        collectionView.dataSource = nil
    }
}

// MARK: - UICollectionViewDataSource, UICollectionViewDelegate

extension YJCustomCycleCollectionView : UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return totalItemsCount
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var tempIndexPath = indexPath
        tempIndexPath.item %= originItemsCount
        return delegate?.collectionView(self, cellForItemAt: tempIndexPath) ?? UICollectionViewCell()
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        didSelectItemBlock?(indexPath.item % originItemsCount)
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return paddingInset
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return realItemSize
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return minimumLineSpacing
    }
    
//    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
//        return minimumInteritemSpacing
//    }
}

// MARK: - UIScrollViewDelegate
extension YJCustomCycleCollectionView: UIScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {}
    
    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        // velocity.y表示在将要离开拖动的时候的方向（-，+），速率；y==0就是没有速率的拖动
        /// 获取当前速率
        var currentRate = velocity.x
        if scrollDirection == .vertical {
            currentRate = velocity.y
        }
        self.rate = (currentRate > 0 || currentRate < 0)
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        //decelerate 表示在手指离开拖动的时候是否有速度
        if self.rate == false && decelerate == false {
            scrollViewDidEndScrollingAnimation(collectionView)
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if self.rate == true {
            scrollViewDidEndScrollingAnimation(collectionView)
        }
    }
    
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        
        guard let collectionView = scrollView as? UICollectionView else { return }
        let count = originItemsCount
        /// 分页修正
        if isPagingEnabled {
            let itemIndex = currentIndex()
            var point = collectionView.contentOffset
            
            let maxX = scrollView.contentSize.width - scrollView.frame.width
            let maxY = scrollView.contentSize.height - scrollView.frame.height
            /// 添加min 优化最后一个不符合分页的问题
            switch scrollDirection {
            case .horizontal:
        
                let X = min(maxX, (realItemSize.width + minimumLineSpacing) * CGFloat(itemIndex))
                
                point = CGPoint(x: X, y: point.y)
            default:
                
                let Y = min(maxY, (realItemSize.height + minimumLineSpacing) * CGFloat(itemIndex))
                point = CGPoint(x: point.x, y: Y)
            }
            collectionView.setContentOffset(point, animated: true)
            /// 判断用于修正修正过程中再次触发动画引起的重复调用问题 排除零点和最后一个格时的非对齐状态
            if scrollView.contentOffset != point ||
                (point.x == 0 && point.y == 0) ||
                (point.x == maxX && maxX > 0) ||
                (point.y == maxY && maxY > 0) {
                didScrollItemOperationBlock?(itemIndex % originItemsCount, nil)
            }
            
        } else {
            /// 计算原始的item偏移量
            var point = self.collectionView.contentOffset
            var width : CGFloat = 0
            var height : CGFloat = 0
            switch scrollDirection {
            case .horizontal:
                width = realItemSize.width + self.minimumLineSpacing
                point.x = scrollView.contentOffset.x.truncatingRemainder(dividingBy: width * CGFloat(count))
            default:
                height = realItemSize.height + self.minimumLineSpacing
                point.y = scrollView.contentOffset.y.truncatingRemainder(dividingBy: height * CGFloat(count))
            }
            didScrollItemOperationBlock?(nil, point)
        }
        
        fixInfiniteLoopLocation()
    }
    
    /// 无限循环进行位置修正
    func fixInfiniteLoopLocation() {
        let count = originItemsCount
        if isInfiniteLoop {
            let itemIndex = currentIndex()
            let tempfixScale = min(max(fixScale, 0), 1)
            if tempfixScale == 0 { return }
            
            var position = UICollectionView.ScrollPosition.left
            var isNeedFix = false
            var width : CGFloat = 0
            var height : CGFloat = 0
            switch scrollDirection {
            case .horizontal:
                position = .left
                width = realItemSize.width + self.minimumLineSpacing
                isNeedFix = collectionView.contentOffset.x < collectionView.contentSize.width * tempfixScale || collectionView.contentOffset.x > collectionView.contentSize.width * (1 - tempfixScale)
            default:
                position = .top
                height = realItemSize.height + self.minimumLineSpacing
                isNeedFix = collectionView.contentOffset.y < collectionView.contentSize.height * tempfixScale || collectionView.contentOffset.y > collectionView.contentSize.height * (1 - tempfixScale)
            }
            
            if isNeedFix {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+0.2) {
                    
                    if self.isPagingEnabled {
                        let targetIndex : Float = Float(self.totalItemsCount) * 0.5 + Float(itemIndex % count)
                        self.collectionView.scrollToItem(at: IndexPath(item: Int(targetIndex), section: 0), at: position, animated: false)
                    } else {
                        var point = self.collectionView.contentOffset
                        if width > 0 {
                            let X = CGFloat(self.totalItemsCount/2) * width + self.collectionView.contentOffset.x.truncatingRemainder(dividingBy: width * CGFloat(count))
                            point = CGPoint(x: X, y: point.y)
                        } else if height > 0 {
                            let Y = CGFloat(self.totalItemsCount/2) * height + self.collectionView.contentOffset.y.truncatingRemainder(dividingBy: height * CGFloat(count))
                            point = CGPoint(x: point.x, y: Y)
                        }
                        self.collectionView.setContentOffset(point, animated: false)
                    }
                }
            }
        }
    }
    
    func currentIndex() -> Int {
        if collectionView.frame.width <= 0 || collectionView.frame.height <= 0 {
            return 0
        }
        var index = 0

        switch scrollDirection {
        case .horizontal:
            index = Int((collectionView.contentOffset.x + realItemSize.width * 0.5) / (realItemSize.width + self.minimumLineSpacing))
        default:
            index = Int((collectionView.contentOffset.y + realItemSize.height * 0.5) / (realItemSize.height + self.minimumLineSpacing))
        }
        return max(0, index)
    }
}
