//
//  YJCycleCollectionView.swift
//  CollectionViewPage
//
//  Created by love on 2020/8/25.
//  Copyright © 2020 symbio. All rights reserved.
//

import UIKit

@objc public protocol YJCycleCollectionViewDelegate : NSObjectProtocol {
    func collectionView(_ collectionView: YJCycleCollectionView, numberOfItemsInSection section: Int) -> Int
    func collectionView(_ collectionView: YJCycleCollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
}

public class YJCycleCollectionView: UIView {

    // MARK: - public
    /// 监听点击
    @objc public var didSelectItemBlock : ((_ currentIndex: Int) -> (Void))?
    
    /// 监听滚动的结果 currentIndex 翻页滚动时返回   offset 滚动偏移量
    @objc public var didScrollItemOperationBlock : ((_ currentIndex: Int , _ offset: CGPoint) -> (Void))?
    
    /// 外边距
    @objc public var marginInset : UIEdgeInsets = .zero {
        didSet {
            guard let _ = superview, frame != .zero else { return }
            setNeedsLayout()
            layoutIfNeeded()
            reloadData()
        }
    }
    /// 内边距
    @objc public var paddingInset : UIEdgeInsets = .zero {
        didSet {
            reloadData()
        }
    }
    
    /** 自动滚动间隔时间,默认2s */
    @objc public var autoScrollTimeInterval : TimeInterval = 2 {
        didSet {
            isAutoScroll ? setupTimer() : invalidateTimer()
        }
    }
    /** 是否自动滚动,默认false */
    @objc public var isAutoScroll : Bool = false {
        didSet {
            isAutoScroll ? setupTimer() : invalidateTimer()
        }
    }
    
    /// 是否无限循环
    @objc public var isInfiniteLoop : Bool = true {
        didSet {
            fixInfiniteLoopLocation()
            reloadData()
        }
    }
    /// 修正比例，无限循环条件下生效，阈值 0-1， 0 不修正， 1持续修正
    @objc public var fixScale : CGFloat = 0.1
    /// 方向
    @objc public var scrollDirection : UICollectionView.ScrollDirection = .horizontal {
        didSet {
            if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                layout.scrollDirection = scrollDirection
            }
            fixInfiniteLoopLocation()
            reloadData()
        }
    }
    
    /// item 宽高比(竖向 高宽比)，默认1 如果想指定大小，设置为0, 阈值[0,5]
    @objc public var itemSizeScale : CGFloat = 1 {
        didSet {
           reloadData()
        }
    }
    /// 高度不能大于frame - 内边距，否则按照比例自动缩减
    @objc public var itemSize : CGSize = .zero {
        didSet {
           reloadData()
        }
    }
    
    /// 是否按页操作
    @objc public var isPagingEnabled : Bool = true {
        didSet {
            collectionView.collectionViewLayout = isPagingEnabled ? customFlowLayout : systemFlowLayout
            reloadData()
        }
    }
    
    /// 间距
    @objc public var minimumLineSpacing : CGFloat = 0 {
        didSet {
            reloadData()
        }
    }
    
    @objc weak open var delegate: YJCycleCollectionViewDelegate?
    
    @objc open func register(_ cellClass: AnyClass?, forCellWithReuseIdentifier identifier: String) {
        collectionView.register(cellClass, forCellWithReuseIdentifier: identifier)
    }

    @objc open func register(nib: UINib?, forCellWithReuseIdentifier identifier: String) {
        collectionView.register(nib, forCellWithReuseIdentifier: identifier)
    }
    
    @objc open func dequeueReusableCell(withReuseIdentifier identifier: String, for indexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath)
    }
    
    @objc open func reloadData() {
        originItemsCount = delegate?.collectionView(self, numberOfItemsInSection: 0) ?? 0
        collectionView.reloadData()
    }
    // MARK: - fileprivate
    /// 真实大小
    fileprivate var realItemSize: CGSize {
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
    fileprivate var rate: Bool = false
    
    fileprivate var timer: DispatchSourceTimer?
        
    /// 真实数量
    fileprivate var totalItemsCount: Int {
        get {
            originItemsCount * (isInfiniteLoop ? 200 : 1)
        }
    }
    
    /// 原始数量
    fileprivate var originItemsCount: Int = 0
    
    fileprivate var systemFlowLayout: UICollectionViewFlowLayout {
        get {
            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = scrollDirection
            return layout
        }
    }
    
    fileprivate var customFlowLayout: YJCycleCollectionViewFlowLayout {
        get {
            let layout = YJCycleCollectionViewFlowLayout()
            layout.scrollDirection = scrollDirection
            return layout
        }
    }
    
    fileprivate lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: self.bounds, collectionViewLayout: isPagingEnabled ? customFlowLayout : systemFlowLayout)
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.scrollsToTop = false
        collectionView.isPagingEnabled = false
        collectionView.decelerationRate = .fast
        addSubview(collectionView)
        return collectionView
    }()
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        if frame == .zero { return }
        let x = marginInset.left
        let y = marginInset.top
        let width = bounds.width - marginInset.left - marginInset.right
        let height = bounds.height - marginInset.top - marginInset.bottom
        collectionView.frame = CGRect(x: x, y: y, width: width, height: height)
        
        /// 无限循环模式下调整位置
        if collectionView.contentOffset.x == 0 && totalItemsCount > 0 && isInfiniteLoop {
            let targetIndex : Float = Float(totalItemsCount) * 0.5
            collectionView.scrollToItem(at: IndexPath(item: Int(targetIndex), section: 0), at: scrollDirection == .horizontal ? .left : .top, animated: false)
        }
    }
    
    deinit {
        collectionView.delegate = nil
        collectionView.dataSource = nil
    }
}

// MARK: - UICollectionViewDataSource, UICollectionViewDelegate

extension YJCycleCollectionView : UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
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
}

// MARK: - UIScrollViewDelegate
extension YJCycleCollectionView: UIScrollViewDelegate {
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if isAutoScroll { invalidateTimer() }
    }
    
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
        if isAutoScroll { setupTimer() }
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if self.rate { scrollViewDidEndScrollingAnimation(collectionView) }
    }
    
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        didScrollItemOperationBlock?(isPagingEnabled ? (currentIndex() % originItemsCount) : -1, originOffet(scrollView))
        fixInfiniteLoopLocation()
    }

    
    /// 提取原始偏移量
    /// - Parameter scrollView: scrollView
    /// - Returns: 偏移量
    func originOffet(_ scrollView: UIScrollView) -> CGPoint {
        /// 计算原始的item偏移量
        var point = self.collectionView.contentOffset
        var width : CGFloat = 0
        var height : CGFloat = 0
        switch scrollDirection {
        case .horizontal:
            width = realItemSize.width + self.minimumLineSpacing
            point.x = scrollView.contentOffset.x.truncatingRemainder(dividingBy: width * CGFloat(originItemsCount))
        default:
            height = realItemSize.height + self.minimumLineSpacing
            point.y = scrollView.contentOffset.y.truncatingRemainder(dividingBy: height * CGFloat(originItemsCount))
        }
        return point
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
    
    
    /// 获取当前的真实下标
    /// - Returns: 下标
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
    
    func invalidateTimer() {
        timer?.cancel()
        timer = nil
    }
    
    func setupTimer() {
        invalidateTimer()
        timer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue.global())
        timer?.schedule(deadline: .now(), repeating: autoScrollTimeInterval)
        timer?.setEventHandler(handler: { [weak self] in
            DispatchQueue.main.async {
                self?.automaticScroll()
            }
        })
        timer?.resume()
    }

    func automaticScroll() {
        if totalItemsCount == 0 { return }
        scroll(to: currentIndex() + 1)
    }
    
    func scroll(to index: Int) {
        var targetIndex = index
        let position: UICollectionView.ScrollPosition = scrollDirection == .horizontal ? .left : .top
        
        if targetIndex >= totalItemsCount {
            if isInfiniteLoop {
                targetIndex = Int(Float(totalItemsCount) * 0.5)
                self.collectionView.scrollToItem(at: IndexPath(item: Int(targetIndex), section: 0), at: position, animated: true)
            }
            return
        }
        self.collectionView.scrollToItem(at: IndexPath(item: Int(targetIndex), section: 0), at: position, animated: true)
    }
}

class YJCycleCollectionViewFlowLayout: UICollectionViewFlowLayout {
    /// 规定超过这个滚动速度就强制翻页，从而使翻页更容易触发。默认为 0.4
    var flickVelocity: CGFloat = 0.4
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        
        guard let collectionView = collectionView, let view = collectionView.delegate as? YJCycleCollectionView else { return super.targetContentOffset(forProposedContentOffset: proposedContentOffset, withScrollingVelocity: velocity) }
        
        let currentItemSize = view.collectionView(collectionView, layout: self, sizeForItemAt: IndexPath(item: 0, section: 0))
        let currentMinimumLineSpacing = view.collectionView(collectionView, layout: self, minimumLineSpacingForSectionAt: 0)
        
        
        let pageWidth: CGFloat = currentItemSize.width + currentMinimumLineSpacing
        
        let pageHeight : CGFloat = currentItemSize.height  + currentMinimumLineSpacing
        
        switch scrollDirection {
        case .horizontal:
            return page(width: pageWidth, velocity: velocity, collectionView: collectionView, proposedContentOffset: proposedContentOffset)
        default:
            return page(height: pageHeight, velocity: velocity, collectionView: collectionView, proposedContentOffset: proposedContentOffset)
        }
    }
    
    /// 获取横向要偏移的位置
    func page(width : CGFloat, velocity: CGPoint, collectionView: UICollectionView, proposedContentOffset: CGPoint) -> CGPoint {
        let rawPageValue = collectionView.contentOffset.x / width
        let currentPage = velocity.x > 0 ? floor(rawPageValue) : ceil(rawPageValue)
        let nextPage = velocity.x > 0 ? ceil(rawPageValue) : floor(rawPageValue)
        let pannedLessThanAPage = abs(1 + currentPage - rawPageValue) > 0.5
        
        let flicked = abs(velocity.x) > flickVelocity
        
        var offset = proposedContentOffset
        
        if pannedLessThanAPage && flicked {
            offset.x = nextPage * width
        } else {
            offset.x = round(rawPageValue) * width
        }
        return offset
    }
    
    /// 获取纵向要偏移的位置
    func page(height : CGFloat, velocity: CGPoint, collectionView: UICollectionView, proposedContentOffset: CGPoint) -> CGPoint {
        let rawPageValue = collectionView.contentOffset.y / height
        let currentPage = velocity.y > 0 ? floor(rawPageValue) : ceil(rawPageValue)
        let nextPage = velocity.y > 0 ? ceil(rawPageValue) : floor(rawPageValue)
        let pannedLessThanAPage = abs(1 + currentPage - rawPageValue) > 0.5
        let flicked = abs(velocity.y) > flickVelocity
        
        var offset = proposedContentOffset
        
        if pannedLessThanAPage && flicked {
            offset.y = nextPage * height
        } else {
            offset.y = round(rawPageValue) * height
        }
        return offset
    }
}
