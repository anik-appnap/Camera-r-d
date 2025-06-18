//
//  FilterSelectionView.swift
//  Camera r&d
//
//  Created by Appnap WS05 on 6/3/25.
//

import UIKit

// MARK: - FilterSelectionView
protocol FilterSelectionViewDelegate: AnyObject{
    func didSelectFilter(newFilter: CameraFilter)
    func didSelectFilter(newFilter: CIFilter)
}

class FilterSelectionView: UIView, UITableViewDelegate, UITableViewDataSource {

    private let tableView = UITableView()
    private let filters = CIImageFilterManager.shared.filters
    private var selectedIndex: Int? = nil
    
    weak var delegate: FilterSelectionViewDelegate?

    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTableView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTableView()
    }

    private func setupTableView() {
        addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: self.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: self.trailingAnchor)
        ])
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "FilterCell")
    }

    // MARK: - UITableView DataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filters.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FilterCell", for: indexPath)
        let filter = filters[indexPath.row]
        let attributes = filter.attributes
        if let displayName = attributes[kCIAttributeFilterDisplayName] as? String{
            cell.textLabel?.text = "🎨 \(displayName)"
        }
        else{
            cell.textLabel?.text = "🎨 \(filter.name)"
        }
        
        cell.textLabel?.font = .systemFont(ofSize: 14)
        if indexPath.row == selectedIndex{
            cell.backgroundColor = .gray.withAlphaComponent(0.4)
        }
        else{
            cell.backgroundColor = .clear
        }
        return cell
    }

    // MARK: - UITableView Delegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedFilter = filters[indexPath.row]
        delegate?.didSelectFilter(newFilter: selectedFilter)
        tableView.deselectRow(at: indexPath, animated: true)
        let previousIndex = selectedIndex
        selectedIndex = indexPath.row
        tableView.reloadRows(at: [indexPath, IndexPath(row: previousIndex ?? 0, section: 0)], with: .fade)
    }
}
