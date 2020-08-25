//
//  SystemViewController.swift
//  CollectionViewPage
//
//  Created by love on 2020/8/25.
//  Copyright © 2020 symbio. All rights reserved.
//

import UIKit

class SystemViewController: UIViewController {

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
    
    lazy var collectionView1: UICollectionView = {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .horizontal
        flowLayout.minimumLineSpacing = 0
        flowLayout.itemSize = CGSize(width: UIScreen.main.bounds.width, height: 200)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        collectionView.register(CMSCollectionViewCell.self, forCellWithReuseIdentifier: "CMSCollectionViewCell")
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isPagingEnabled = true
        collectionView.frame = CGRect(x: 0, y: 100, width: UIScreen.main.bounds.width, height: 200)
        view.addSubview(collectionView)
        return collectionView
    }()
    

    lazy var collectionView2: UICollectionView = {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .horizontal
        flowLayout.minimumLineSpacing = 0
        flowLayout.itemSize = CGSize(width: UIScreen.main.bounds.width - 40, height: 200)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        collectionView.register(CMSCollectionViewCell.self, forCellWithReuseIdentifier: "CMSCollectionViewCell")
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isPagingEnabled = true
        collectionView.frame = CGRect(x: 0, y: 400, width: UIScreen.main.bounds.width, height: 200)
        view.addSubview(collectionView)
        return collectionView
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .lightGray
        // Do any additional setup after loading the view.
        collectionView1.reloadData()
        collectionView2.reloadData()
        
        /// 系统的collectionView翻页机制是根据当前collectionView的宽度来决定，也就是说，当item的 宽度刚好等于collectionView的宽度时，系统翻页效果是正常的，否则会出现翻页到item中间的情况
        
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension SystemViewController : UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CMSCollectionViewCell", for: indexPath) as! CMSCollectionViewCell
        cell.model = dataSource[indexPath.item]
        cell.backgroundColor = .red
        return cell
    }
    
    
}
