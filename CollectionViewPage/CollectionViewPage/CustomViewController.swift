//
//  CustomViewController.swift
//  CollectionViewPage
//
//  Created by love on 2020/8/25.
//  Copyright © 2020 symbio. All rights reserved.
//

import UIKit

class CustomViewController: UIViewController {

    var collectionView = YJCustomCycleCollectionView()
        
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
            view.backgroundColor = .lightGray
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
        }
}

extension CustomViewController : YJCustomCycleCollectionViewDelegate {
    func collectionView(_ collectionView: YJCustomCycleCollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func collectionView(_ collectionView: YJCustomCycleCollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CMSCollectionViewCell", for: indexPath) as! CMSCollectionViewCell
        cell.model = dataSource[indexPath.item]
        cell.backgroundColor = .red
        return cell
    }
}
