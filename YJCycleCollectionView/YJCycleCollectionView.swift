//
//  YJCycleCollectionView.swift
//  test
//
//  Created by love on 2020/8/21.
//  Copyright © 2020 bonree. All rights reserved.
//

import UIKit

@objc public protocol YJCycleCollectionViewDelegate : NSObjectProtocol {
    func collectionView(_ collectionView: YJCycleCollectionView, numberOfItemsInSection section: Int) -> Int
    func collectionView(_ collectionView: YJCycleCollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    @objc optional func collectionView(_ collectionView: YJCycleCollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
}

/// 滚动模式
@objc public enum YJCycleScrollType : Int {
    /// 分页式滚动
    case page = 0
    /// 匀速滚动
    case constantSpeed = 1
}

public class YJCycleCollectionView: UIView {

    // MARK: - public
    
    // MARK: - UI控制API
    /// 外边距
    @objc public var marginInset: UIEdgeInsets = .zero {
        didSet {
            guard let _ = superview, frame != .zero else { return }
            setNeedsLayout()
            layoutIfNeeded()
            reloadData()
        }
    }
    /// 内边距
    @objc public var paddingInset: UIEdgeInsets = .zero {
        didSet {
            reloadData()
        }
    }
    
    /// item 宽高比(竖向 高宽比)，默认0 如果想指定大小，设置为0, 阈值[0,5]
    @objc public var itemSizeScale: CGFloat = 0 {
        didSet {
           reloadData()
        }
    }
    /// 高度不能大于frame - 内边距，否则按照比例自动缩减
    @objc public var itemSize: CGSize = .zero {
        didSet {
           reloadData()
        }
    }
    /// 间距
    @objc public var minimumLineSpacing: CGFloat = 0 {
        didSet {
            reloadData()
        }
    }
    
    // MARK: - 滚动控制API
    /// 监听点击
    @objc public var didSelectItemBlock: ((_ currentIndex: Int) -> (Void))?
    
    /// 监听滚动的结果 currentIndex 翻页滚动时返回   offset 滚动偏移量
    @objc public var didScrollItemOperationBlock: ((_ currentIndex: Int , _ offset: CGPoint) -> (Void))?
    
    /// 是否可用滑动手势
    @objc public var isEnabledPanGestureRecognizer: Bool = false {
        didSet {
            // 存储这一瞬间的contentOffset值
            let storePoint = collectionView.contentOffset
            // 禁止用pan手势(禁用pan手势瞬间会导致contenOffset值瞬间恢复成(0, 0))
            collectionView.panGestureRecognizer.isEnabled = isEnabledPanGestureRecognizer
            collectionView.isScrollEnabled = isEnabledPanGestureRecognizer
            collectionView.contentOffset = storePoint
        }
    }
    
    /// 滚动模式
    @objc public var scrollType: YJCycleScrollType = .page {
        didSet {
            if scrollType == .constantSpeed {
                isPagingEnabled = false
            } else {
                isAutoScroll ? setupTimer() : invalidateTimer()
            }
        }
    }
    
    /// 滚动模式下生效，滚动速度,每秒所滚动的单位
    @objc public var scrollSpeed: CGFloat = 60
    
    /** 自动滚动间隔时间,默认2.5s */
    @objc public var autoScrollTimeInterval: TimeInterval = 2.5 {
        didSet {
            isAutoScroll ? setupTimer() : invalidateTimer()
        }
    }
    /** 是否自动滚动,默认false */
    @objc public var isAutoScroll: Bool = false {
        didSet {
            isAutoScroll ? setupTimer() : invalidateTimer()
        }
    }
    
    /// 是否无限循环
    @objc public var isInfiniteLoop: Bool = true {
        didSet {
            fixInfiniteLoopLocation()
            reloadData()
        }
    }
    /// 修正比例，无限循环条件下生效，阈值 0-1， 0 不修正， 1持续修正
    @objc public var fixScale: CGFloat = 0.1
    /// 方向
    @objc public var scrollDirection: UICollectionView.ScrollDirection = .horizontal {
        didSet {
            if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                layout.scrollDirection = scrollDirection
            }
            fixInfiniteLoopLocation()
            reloadData()
        }
    }
    
    /// 是否按页操作
    @objc public var isPagingEnabled: Bool = true {
        didSet {
            if isPagingEnabled && scrollType == .constantSpeed {
                isPagingEnabled = false
            } else {
                collectionView.collectionViewLayout = isPagingEnabled ? customFlowLayout : systemFlowLayout
                reloadData()
            }
        }
    }
    
    @objc weak open var delegate: YJCycleCollectionViewDelegate?
    
    @objc open func register(_ cellClass: AnyClass?, forCellWithReuseIdentifier identifier: String) {
        collectionView.register(cellClass, forCellWithReuseIdentifier: identifier)
    }

    @objc open func register(nib: UINib?, forCellWithReuseIdentifier identifier: String) {
        collectionView.register(nib, forCellWithReuseIdentifier: identifier)
    }
    
    @objc open func dequeueReusableCell(withReuseIdentifier identifier: String, forIndexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: forIndexPath)
    }
    
    @objc open func reloadData() {
        originItemsSizes.removeAll()
        originItemsCount = delegate?.collectionView(self, numberOfItemsInSection: 0) ?? 0
        collectionView.reloadData()
    }
    
    // MARK: - fileprivate
    
    /// 是否有速度,用于判定何时结束
    fileprivate var rate: Bool = false
    /// 真实数据与原始数据的比例
    fileprivate var dataCountRatio: Int = 200
    fileprivate var timer: DispatchSourceTimer?
    
    fileprivate var displayLink: CADisplayLink?
    
    /// 原始数量
    fileprivate var originItemsCount: Int = 0
    /// 记录items size
    var originItemsSizes: [CGSize] = []
    /// 最后一次的下标
    var lastIndex: Int = 0
    
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
            fixInfiniteLoopLocation()
        }
    }

    deinit {
        collectionView.delegate = nil
        collectionView.dataSource = nil
    }
}

// MARK: - UICollectionViewDataSource, UICollectionViewDelegate

extension YJCycleCollectionView: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
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
        var tempIndexPath = indexPath
        tempIndexPath.item %= originItemsCount
        let itemSize = delegate?.collectionView?(self, layout: collectionViewLayout, sizeForItemAt: tempIndexPath) ?? realItemSize
        /// 记录真实的item size
        if originItemsCount > indexPath.item && originItemsSizes.count < originItemsCount { originItemsSizes.append(itemSize) }
        
        return itemSize
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
//        let value = scrollDirection == .horizontal ? 0 : minimumLineSpacing
        return minimumLineSpacing
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return minimumLineSpacing
//        return scrollDirection == .vertical ? 0 : minimumLineSpacing
    }
}

extension YJCycleCollectionView {
    
    /// 真实数量
    fileprivate var totalItemsCount: Int {
        get { originItemsCount * (isInfiniteLoop ? dataCountRatio : 1) }
    }
    
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
    
    /// 真实大小
    fileprivate var realItemSize: CGSize {
        get {
            let tempScale = min(5, max(0, itemSizeScale))

            switch scrollDirection {
            case .horizontal:
                var maxSizeWidth = self.frame.width - paddingInset.left - paddingInset.right - marginInset.left - marginInset.right
                maxSizeWidth = max(0, maxSizeWidth)
                var maxSizeHeight = self.frame.height - paddingInset.top - paddingInset.bottom - marginInset.top - marginInset.bottom
                maxSizeHeight = max(0, maxSizeHeight)
                /// 需要指定size
                if tempScale == 0 {
                    if itemSize == .zero { // 默认充满
                        return CGSize(width: maxSizeWidth, height: maxSizeHeight)
                    }
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
                var maxSizeWidth = self.frame.width - paddingInset.left - paddingInset.right - marginInset.left - marginInset.right
                maxSizeWidth = max(0, maxSizeWidth)
                var maxSizeHeight = self.frame.height - paddingInset.top - paddingInset.bottom - marginInset.top - marginInset.bottom
                maxSizeHeight = max(0, maxSizeHeight)
                /// 需要指定size
                if tempScale == 0 {
                    
                    if itemSize == .zero { // 默认充满
                        return CGSize(width: maxSizeWidth, height: maxSizeHeight)
                    }
                    
                    /// 该size可用
                    if maxSizeWidth >= itemSize.width {
                        return itemSize
                    }
                    let tempSizeScale = itemSize.width / itemSize.height
                    let newSize = CGSize(width: maxSizeWidth, height: maxSizeWidth / tempSizeScale)
                    return newSize
                }

                let newSize = CGSize(width: maxSizeWidth , height: maxSizeWidth * itemSizeScale)
                return newSize
            @unknown default:
                fatalError()
            }
        }
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
        if self.rate {
            scrollViewDidEndScrollingAnimation(collectionView)
        }
    }
    
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        
        let index = currentIndex()
        lastIndex = index
        
        didScrollItemOperationBlock?(isPagingEnabled ? (index % originItemsCount) : -1, originOffset(scrollView.contentOffset))
        
        fixInfiniteLoopLocation()
    }
    
    /// 原始的内容大小
    fileprivate var originContentSize: CGSize {
        get {
            var contentWith: CGFloat = 0
            var contentHeight: CGFloat = 0
            
            switch scrollDirection {
            case .horizontal:
                for size in originItemsSizes {
                    contentHeight = size.height
                    contentWith += (size.width + minimumLineSpacing)
                }
            default:
                for size in originItemsSizes {
                    contentHeight += (size.height + minimumLineSpacing)
                    contentWith = size.width
                }
            }
            return CGSize(width: contentWith, height: contentHeight)
        }
    }
    
    /// 提取相对偏移量
    /// - Parameter scrollView: scrollView
    /// - Returns: 偏移量
    func originOffset(_ contentOffset: CGPoint) -> CGPoint {
        /// 计算原始的item偏移量
        var point = contentOffset
        let size = originContentSize
        switch scrollDirection {
        case .horizontal:
            if size.width > 0 {
                point.x = contentOffset.x.truncatingRemainder(dividingBy: size.width)
            }
        default:
            if size.height > 0 {
                point.y = contentOffset.y.truncatingRemainder(dividingBy: size.height)
            }
        }
        return point
    }
    
    /// 无限循环进行位置修正
    func fixInfiniteLoopLocation() {
        if isInfiniteLoop {
            let itemIndex = currentIndex()
            let tempfixScale = min(max(fixScale, 0), 1)
            if tempfixScale == 0 { return }

            var position = UICollectionView.ScrollPosition.left
            var isNeedFix = false
            switch scrollDirection {
            case .horizontal:
                position = .left
                isNeedFix = collectionView.contentOffset.x < collectionView.contentSize.width * tempfixScale || collectionView.contentOffset.x > collectionView.contentSize.width * (1 - tempfixScale)
            default:
                position = .top
                isNeedFix = collectionView.contentOffset.y < collectionView.contentSize.height * tempfixScale || collectionView.contentOffset.y > collectionView.contentSize.height * (1 - tempfixScale)
            }

            if isNeedFix {
                var point = self.collectionView.contentOffset
                let offset = originOffset(collectionView.contentOffset)
                
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()) {

                    if self.isPagingEnabled {
                        let targetIndex : Float = Float(self.totalItemsCount) * 0.5 + Float(itemIndex % self.originItemsCount)
                        self.lastIndex = Int(targetIndex)
                        self.collectionView.scrollToItem(at: IndexPath(item: Int(targetIndex), section: 0), at: position, animated: false)
                    } else {
                        if self.scrollDirection == .horizontal {
                            let X = CGFloat(self.dataCountRatio) / 2 * self.originContentSize.width + offset.x
                            point = CGPoint(x: X, y: point.y)
                        } else {
                            let Y = CGFloat(self.dataCountRatio) / 2 * self.originContentSize.height + offset.y
                            point = CGPoint(x: point.x, y: Y)
                        }
                        self.lastIndex = Int(self.index(for: point))
                        self.collectionView.setContentOffset(point, animated: false)
                    }
                }
            }
        }
    }
    
    /// 对真实的下标进行四舍五入
    func currentIndex() -> Int {
        if collectionView.frame.width <= 0 || collectionView.frame.height <= 0 {
            return 0
        }
        return Int(round(index(for: collectionView.contentOffset)))
    }
    
    /// 获取当前的真实下标
    func index(for offset: CGPoint) -> CGFloat {
        var index: CGFloat = 0
        let tempOffset = originOffset(offset)
        
        var sumW: CGFloat = 0
        var sumH: CGFloat = 0
        
        switch scrollDirection {
        case .horizontal:
            if originContentSize.width <= 0 { return 0 }
            
            for (idx, size) in originItemsSizes.enumerated() {
                if tempOffset.x - sumW <= size.width + minimumLineSpacing  {
                    index = CGFloat(idx + Int(offset.x / originContentSize.width) * originItemsCount)
                    index += (tempOffset.x - sumW) / (size.width + minimumLineSpacing)
                    return max(0, index)
                } else {
                    sumW += (size.width + minimumLineSpacing)
                }
            }
        default:
            if originContentSize.height <= 0 { return 0 }
            
            for (idx, size) in originItemsSizes.enumerated() {
                if tempOffset.y - sumH <= size.height + minimumLineSpacing  {
                    index = CGFloat(idx + Int(offset.y / originContentSize.height) * originItemsCount)
                    index += (tempOffset.y - sumH) / (size.height + minimumLineSpacing)
                    return max(0, index)
                } else {
                    sumH += (size.height + minimumLineSpacing)
                }
            }
        }
        return max(0, index)
    }
    
    @objc public func invalidateTimer() {
        timer?.cancel()
        timer = nil
        
        displayLink?.isPaused = true
        displayLink = nil
    }
    
    @objc public func setupTimer() {
        invalidateTimer()
        
        if scrollType == .page {
            timer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue.global())
            timer?.schedule(deadline: .now() + autoScrollTimeInterval, repeating: autoScrollTimeInterval)
            timer?.setEventHandler(handler: { [weak self] in
                DispatchQueue.main.async {
                    self?.automaticScroll()
                }
            })
            timer?.resume()
        } else {
            displayLink = CADisplayLink.yj_scheduledTimer(target: self, selector: #selector(updateContentOffset))
        }
    }

    @objc func updateContentOffset() {
        var point = self.collectionView.contentOffset
        let offset = scrollSpeed / 60
        
        if scrollDirection == .horizontal {
            point.x += offset
        } else {
            point.y += offset
        }
        self.collectionView.setContentOffset(point, animated: false)
        fixInfiniteLoopLocation()
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
    fileprivate var flickVelocity: CGFloat = 0.4
    /// 是否支持一次滑动可以滚动多个 item
    fileprivate var allowsMultipleItemScroll: Bool = false
    /// 规定了当支持一次滑动允许滚动多个 item 的时候，滑动速度要达到多少才会滚动多个 item，默认为 2.5, 仅当 allowsMultipleItemScroll 为 YES 时生效
    fileprivate var multipleItemScrollVelocityLimit: CGFloat = 2.5
    /// 当前 cell 的百分之多少滚过临界点时就会触发滚到下一张的动作，默认为 .666，也即超过 2/3 即会滚到下一张, 对应地，触发滚到上一张的临界点将会被设置为 (1 - pagingThreshold)
    fileprivate var pagingThreshold: CGFloat = 1/3
    /// 是否按照最大翻页进行处理
    fileprivate var isMaximumPage: Bool = true
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard let collectionView = collectionView, let view = collectionView.delegate as? YJCycleCollectionView else { return super.targetContentOffset(forProposedContentOffset: proposedContentOffset, withScrollingVelocity: velocity) }
        let currentMinimumLineSpacing = view.collectionView(collectionView, layout: self, minimumLineSpacingForSectionAt: 0)
        let contentSize = collectionViewContentSize
        let frameSize = collectionView.bounds.size
        var contentInset = collectionView.contentInset
        if #available(iOS 11.0, *) { contentInset = collectionView.adjustedContentInset }
        
        // 代表 collectionView 期望的实际滚动方向是向右，但不代表手指拖拽的方向是向右，因为有可能此时已经在左边的尽头，继续往右拖拽，松手的瞬间由于回弹，这里会判断为是想向左滚动，但其实你的手指是向右拖拽
        let scrollingToRight = proposedContentOffset.x <= collectionView.contentOffset.x
        let scrollingToBottom = proposedContentOffset.y <= collectionView.contentOffset.y
        
        /// 是否强制翻页
        var forcePaging = false
        /// 当前要偏移的位置
        var currentOffset = proposedContentOffset
        
        if scrollDirection == .vertical {
            if allowsMultipleItemScroll == false || abs(velocity.y) <= abs(multipleItemScrollVelocityLimit) {
                // 一次性滚多次的本质是系统根据速度算出来的 proposedContentOffset 可能比当前 contentOffset 大很多，所以这里既然限制了一次只能滚一页，那就直接取瞬时 contentOffset 即可。
                currentOffset = collectionView.contentOffset
                // 只支持滚动一页 或者 支持滚动多页但是速度不够滚动多页时，允许强制滚动
                if abs(velocity.y) > flickVelocity { forcePaging = true }
            }
            
            // 最顶/最底
            if proposedContentOffset.y <= -contentInset.top || proposedContentOffset.y >= contentSize.height + contentInset.bottom - frameSize.height {
                // iOS 10 及以上的版本，直接返回当前的 contentOffset，系统会自动帮你调整到边界状态，而 iOS 9 及以下的版本需要自己计算
                return proposedContentOffset
            }
            
            let progress = view.index(for: collectionView.contentOffset)
            let currentIndex = Int(progress)
            
            /// 判断是否向下翻页
            let shouldNext = (forcePaging || progress - CGFloat(currentIndex) > pagingThreshold || currentIndex > view.lastIndex) && scrollingToBottom == false && (velocity.y > 0 || progress > CGFloat(view.lastIndex))
            /// 判断是否向上翻页
            let shouldPrev = (forcePaging || progress - CGFloat(currentIndex) > 1 - pagingThreshold || currentIndex < view.lastIndex) && scrollingToBottom == true && (velocity.y < 0 || progress < CGFloat(view.lastIndex))
            
            /// 预计偏移的下标
            var prepareIndex = view.lastIndex
            /// 获取目标偏移下标
            var targetIndex = currentIndex
            
            /// 判定最大翻页限制
            var tempHeight: CGFloat = 0
            if shouldNext {
                targetIndex += 1
                if isMaximumPage {
                    for i in view.lastIndex..<view.totalItemsCount {
                        tempHeight += (view.originItemsSizes[i % view.originItemsCount].height + currentMinimumLineSpacing)
                        if tempHeight > frameSize.height { break }
                        prepareIndex += 1
                    }
                    if prepareIndex == view.lastIndex { prepareIndex += 1 }
                    /// 手动翻页不满足最大翻页效果则进行最大分页
                    if targetIndex < prepareIndex { targetIndex = prepareIndex }
                }
                
            } else if shouldPrev {
                if isMaximumPage {
                    for i in 0..<view.lastIndex-1 {
                        tempHeight += (view.originItemsSizes[(view.lastIndex - 1 - i) % view.originItemsCount].height + currentMinimumLineSpacing)
                        if tempHeight > frameSize.height { break }
                        prepareIndex -= 1
                    }
                    if prepareIndex == view.lastIndex { prepareIndex -= 1 }
                    if targetIndex > prepareIndex { targetIndex = prepareIndex }
                }
            }
            
            view.lastIndex = targetIndex
            
            var offsetY: CGFloat = 0
            
            for i in 0..<Int(targetIndex) {
                offsetY += view.originItemsSizes[i % view.originItemsCount].height
                offsetY += currentMinimumLineSpacing
            }
            
            currentOffset.y = -contentInset.top + offsetY
        } else if scrollDirection == .horizontal {
            if allowsMultipleItemScroll == false || abs(velocity.x) <= abs(multipleItemScrollVelocityLimit) {
                // 一次性滚多次的本质是系统根据速度算出来的 proposedContentOffset 可能比当前 contentOffset 大很多，所以这里既然限制了一次只能滚一页，那就直接取瞬时 contentOffset 即可。
                currentOffset = collectionView.contentOffset
                // 只支持滚动一页 或者 支持滚动多页但是速度不够滚动多页，时，允许强制滚动
                if abs(velocity.x) > flickVelocity { forcePaging = true }
            }
            
            // 最左/最右
            if proposedContentOffset.x <= -contentInset.left || proposedContentOffset.x >= contentSize.width + contentInset.right - frameSize.width {
                // iOS 10 及以上的版本，直接返回当前的 contentOffset，系统会自动帮你调整到边界状态，而 iOS 9 及以下的版本需要自己计算
                return proposedContentOffset
            }
            
            /// 获取瞬时偏移
            let progress = view.index(for: collectionView.contentOffset)
            /// 瞬时偏移向下取整
            let currentIndex = Int(progress)
            
            /// 判断是否向右翻页
            let shouldNext = (forcePaging || progress - CGFloat(currentIndex) > pagingThreshold || currentIndex > view.lastIndex) && scrollingToRight == false && (velocity.x > 0 || progress > CGFloat(view.lastIndex))
            
            /// 判断是否向左翻页
            let shouldPrev = (forcePaging || progress - CGFloat(currentIndex) > 1 - pagingThreshold || currentIndex < view.lastIndex) && scrollingToRight == true && (velocity.x < 0 || progress < CGFloat(view.lastIndex))
            
            /// 预计偏移的下标
            var prepareIndex = view.lastIndex
            /// 获取目标偏移下标
            var targetIndex = currentIndex
            
            /// 判定最大翻页限制
            var tempWith: CGFloat = 0
            if shouldNext {
                targetIndex += 1
                if isMaximumPage {
                    for i in view.lastIndex..<view.totalItemsCount {
                        tempWith += (view.originItemsSizes[i % view.originItemsCount].width + currentMinimumLineSpacing)
                        if tempWith > frameSize.width { break }
                        prepareIndex += 1
                    }
                    if prepareIndex == view.lastIndex { prepareIndex += 1 }
                    /// 手动翻页不满足最大翻页效果则进行最大分页
                    if targetIndex < prepareIndex { targetIndex = prepareIndex }
                }

            } else if shouldPrev {
                if isMaximumPage {
                    for i in 0..<view.lastIndex-1 {
                        tempWith += (view.originItemsSizes[(view.lastIndex - 1 - i) % view.originItemsCount].width + currentMinimumLineSpacing)
                        if tempWith > frameSize.width { break }
                        prepareIndex -= 1
                    }
                    if prepareIndex == view.lastIndex { prepareIndex -= 1 }
                    if targetIndex > prepareIndex { targetIndex = prepareIndex }
                }
            }

            view.lastIndex = targetIndex
            
            var offsetX: CGFloat = 0
            for i in 0..<Int(targetIndex) {
                offsetX += view.originItemsSizes[i % view.originItemsCount].width
                offsetX += currentMinimumLineSpacing
            }
            
            currentOffset.x = -contentInset.left + offsetX
        }
        return currentOffset
    }
}

/// 处理timer强引用类
public class YJWeakTimerProxy: NSObject {
    
    fileprivate weak var target:NSObjectProtocol?
    fileprivate var sel:Selector?
    /// required，实例化timer之后需要将timer赋值给proxy，否则就算target释放了，timer本身依然会继续运行
    public weak var timer:CADisplayLink?
    
    public required init(target:NSObjectProtocol?, sel:Selector?) {
        self.target = target
        self.sel = sel
        super.init()
        // 加强安全保护
        guard target?.responds(to: sel) == true else {
            return
        }
        // 将target的selector替换为redirectionMethod，该方法会重新处理事件
        if let method = class_getInstanceMethod(self.classForCoder, #selector(YJWeakTimerProxy.redirectionMethod)), let sel = sel {
            class_replaceMethod(self.classForCoder, sel, method_getImplementation(method), method_getTypeEncoding(method))
        }
    }
    
    @objc func redirectionMethod () {
        // 如果target未被释放，则调用target方法，否则释放timer
        if self.target != nil {
            self.target!.perform(self.sel)
        } else {
            self.timer?.invalidate()
        }
    }
}

public extension CADisplayLink {
    class func yj_scheduledTimer(target aTarget: NSObjectProtocol, selector aSelector: Selector) -> CADisplayLink {
        let proxy = YJWeakTimerProxy.init(target: aTarget, sel: aSelector)
        let timer = CADisplayLink(target: proxy, selector: aSelector)
        if #available(iOS 10.0, *) {
            timer.preferredFramesPerSecond = 60
        } else {
            // Fallback on earlier versions
            timer.frameInterval = 1
        }
        timer.add(to: RunLoop.current, forMode: .common)
        proxy.timer = timer
        return timer
    }
}
