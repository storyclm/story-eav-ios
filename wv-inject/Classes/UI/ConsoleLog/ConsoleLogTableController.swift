//
//  ConsoleLogTableController.swift
//  wv-inject
//
//  Created by Sergey Ryazanov on 17.05.2021.
//

import UIKit

final class ConsoleLogTableController: UITableViewController {

    private var tabbar: TabBarController? {
        return self.tabBarController as? TabBarController
    }

    typealias ConsoleLogModel = (date: Date, text: String)
    private var logs: [ConsoleLogModel] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.tableFooterView = UIView()
    }

    func addLogMessage(_ message: String) {
        let log = (date: Date(), text: message)

        if self.logs.isEmpty {
            self.logs = [log]
            self.tableView.reloadData()
        } else {
            self.logs.insert(log, at: 0)

            self.tableView.performBatchUpdates {
                self.tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: UITableView.RowAnimation.top)
            } completion: { isFinished in
            }
        }
    }
}

extension ConsoleLogTableController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.logs.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let log = self.logs[indexPath.row]

        let cell = tableView.dequeueReusableCell(withIdentifier: "ConsoleLogId", for: indexPath)
        cell.textLabel?.text = log.text
        cell.detailTextLabel?.text = log.date.asLogDateString()
        return cell
    }
}

fileprivate extension Date {

    func asLogDateString() -> String {
        let df = DateFormatter()
        df.dateFormat = "dd/MM | HH:mm:ss"
        return df.string(from: self)
    }
}
