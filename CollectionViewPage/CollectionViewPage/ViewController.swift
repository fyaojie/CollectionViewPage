//
//  ViewController.swift
//  CollectionViewPage
//
//  Created by love on 2020/8/25.
//  Copyright © 2020 symbio. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let alert = UIAlertController(title: "跳转", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "系统翻页效果", style: .default, handler: { (action) in
            self.navigationController?.pushViewController(SystemViewController(), animated: true)
        }))
        alert.addAction(UIAlertAction(title: "完全自定义翻页效果", style: .default, handler: { (action) in
            self.navigationController?.pushViewController(CustomViewController(), animated: true)
        }))
        alert.addAction(UIAlertAction(title: "模拟系统翻页弹性效果", style: .default, handler: { (action) in
            self.navigationController?.pushViewController(CMSCollectionViewController(), animated: true)
        }))
        present(alert, animated: false, completion: nil)
    }
    

}


