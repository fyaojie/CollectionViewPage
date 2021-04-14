//
//  CMSCollectionViewController.swift
//  CMSPaaSBenchmark
//
//  Created by love on 2020/8/24.
//

import UIKit
import YJCycleCollectionView

class CMSCollectionViewController: UIViewController {

    @IBOutlet weak var infiniteLoopSwitch: UISwitch!
    
    @IBOutlet weak var pagingEnabledSwitch: UISwitch!
    @IBOutlet weak var scrollDirectionSwitch: UISwitch!
    
    @IBOutlet weak var minimumLineSpacingSlider: UISlider!
    @IBOutlet weak var minimumInteritemSpacingSlider: UISlider!
    @IBOutlet weak var marginInsetSlider: UISlider!
    @IBOutlet weak var paddingInsetSlider: UISlider!
    @IBOutlet weak var whScaleSlider: UISlider!
    
    @IBOutlet weak var whSwitch: UISwitch!
    
    var collectionView = YJCycleCollectionView()
    
    var dataSource : [CMSCycleScrollModel] {
        get {
            var arr = [CMSCycleScrollModel]()
            
            for i in 0..<5 {
                let model = CMSCycleScrollModel()
                model.title = "标题\(i)"
                model.changeScale = "+\(i)%"
                model.title = "副标题\(i)"
                arr.append(model)
            }
            return arr
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        // Do any additional setup after loading the view.

        setupUI()
    }
    
    func setupUI() {
        
        view.backgroundColor = .lightGray
        
        collectionView.frame = CGRect(x: 0, y: 100, width: UIScreen.main.bounds.width, height: 200)
        collectionView.delegate = self
        collectionView.register(CMSCollectionViewCell.self, forCellWithReuseIdentifier: "CMSCollectionViewCell")
        collectionView.didSelectItemBlock = {
            index in
            print("点击的当前页为：\(index)")
        }
//        collectionView.itemSize = CGSize(width: 100, height: 200)
        collectionView.didScrollItemOperationBlock = {
            (index, point) in
            print("滑动结束的页为：\(String(describing: index)) \(String(describing: point))")
        }
        collectionView.backgroundColor = .orange
        view.addSubview(collectionView)
        collectionView.reloadData()

        whScaleSlider.value = 0.2
    }

    
    @IBAction func infiniteLoopSwitchChange(_ sender: UISwitch) {
        collectionView.isInfiniteLoop = sender.isOn
    }
    
    @IBAction func pagingEnabledSwitchChange(_ sender: UISwitch) {
        collectionView.isPagingEnabled = sender.isOn
    }
    
    @IBAction func scrollDirectionSwitchChange(_ sender: UISwitch) {
        collectionView.scrollDirection = (sender.isOn == true ? .horizontal : .vertical)
    }
    
    @IBAction func minimumLineSpacingSliderChange(_ sender: UISlider) {
        collectionView.minimumLineSpacing = CGFloat(sender.value * 100)
    }
    
    @IBAction func minimumInteritemSpacingSliderChange(_ sender: UISlider) {
//        collectionView.minimumInteritemSpacing = CGFloat(sender.value * 100)
    }
    @IBAction func marginInsetSliderChange(_ sender: UISlider) {
        let value = CGFloat(sender.value * 100)
        collectionView.marginInset = UIEdgeInsets(top: value, left: value, bottom: value, right: value)
    }
    @IBAction func paddingInsetSliderChange(_ sender: UISlider) {
        let value = CGFloat(sender.value * 100)
        collectionView.paddingInset = UIEdgeInsets(top: value, left: value, bottom: value, right: value)
    }
    @IBAction func whScaleSliderChange(_ sender: UISlider) {
        collectionView.itemSizeScale = CGFloat(sender.value * 5)
    }
    
    @IBAction func whSwitchChange(_ sender: UISwitch) {
        if sender.isOn {
            collectionView.itemSizeScale = 0
            whScaleSlider.value = 0
            whScaleSlider.isEnabled = false
            collectionView.itemSize = CGSize(width: view.bounds.width, height: collectionView.frame.height)
        } else {
            whScaleSlider.isEnabled = true
            whScaleSlider.value = 0.2
            collectionView.itemSizeScale = 1
        }
    }
}

extension CMSCollectionViewController : YJCycleCollectionViewDelegate {
    func collectionView(_ collectionView: YJCycleCollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func collectionView(_ collectionView: YJCycleCollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CMSCollectionViewCell", forIndexPath: indexPath) as! CMSCollectionViewCell
        cell.model = dataSource[indexPath.item]
        cell.backgroundColor = .red
        return cell
    }
}
