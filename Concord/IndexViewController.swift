//
//  IndexViewController.swift
//  Concord
//
//  Created by Raheel Sayeed on 27/10/20.
//  Copyright © 2020 Medical Gear. All rights reserved.
//

import UIKit
import SMARTMarkers
import ResearchKit
import SMART
import SafariServices


class IndexViewController: UITableViewController {

    var taskController: TaskController?
    var sessionController: SessionController?
    var instruments = [Instrument]()
	var records: [Report]?
	
	
	override func viewWillAppear(_ animated: Bool) {
		clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
		super.viewWillAppear(animated)
	}
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		let appVersionString: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String

		let app = UIBarButtonItem(title: "PPMG #\(appVersionString)", style: .plain, target: self, action: #selector(openReleaseNotes(_:)))

		
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Import", style: .plain, target: self, action: #selector(fetchHealthRecords(_:)))
		
		navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Visuals", style: .plain, target: self, action: #selector(showGraphs(_:)))
		
		
		toolbarItems = [
			app,
			UIBarButtonItem(title: "Github", style: .plain, target: self, action: #selector(openLink(_:)))
		]
		
		

    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return records?.count ?? 0
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RCell", for: indexPath)
		let report = records![indexPath.item]
		cell.textLabel?.text = report.rp_title
		cell.detailTextLabel?.text = report.rp_observation
        return cell
    }
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let report = records![indexPath.item]
		let viewer = ReportViewController(report)
		self.present(viewer, animated: true, completion: nil)

	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		
		if let listView = segue.destination as? MasterViewController {
			if let records = self.records {
				listView.healthRecords = sortRecords(records)
			}
		}
		
	}

}



extension IndexViewController {
    
    @objc func fetchHealthRecords(_ sender: Any?) {
        
		let instrument = Instruments.HealthKit.HealthRecords.instance
        
        taskController = TaskController(instrument: instrument)
        
        taskController?.prepareSession(callback: { (task, error) in
            if let controller = task {
                self.present(controller, animated: true, completion: nil)
            }
        })
        
        taskController?.onTaskCompletion = { [unowned self] submissionBundle, error in
            
			// Only get the lab resources:
			
			if let fhir_reports = submissionBundle?.bundle.entry?.filter({ $0.resource is Observation})
				.map({ $0.resource as! Report })
			{
				// This is where the fhir records live
				self.records = fhir_reports
                
                // DEBUG PRINT to console
                print("***********************************")
                print(self.records?.count)
                print(type(of: self.records))
                print("***********************************")
                print(self.records?[0])
                print("***********************************")
                print(self.records?[1].rp_observation)
                print(self.records?[1].rp_date)
                print(type(of: self.records?[1].rp_observation))
                

			}
			else {
				self.records = nil
			}

			
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
	
	
	
	@objc func openLink(_ sender: Any?) {
		let view = SFSafariViewController(url: URL(string: "https://github.com/raheelsayeed/concord-ios")!)
		present(view, animated: true, completion: nil)
	}
	
	@objc func openReleaseNotes(_ sender: Any?) {
		let view = SFSafariViewController(url: URL(string: "https://github.com/raheelsayeed/concord-ios/blob/master/ReleaseNotes.md")!)
		present(view, animated: true, completion: nil)

	}
	
	
	
	@objc func showGraphs(_ sender: Any?) {
		
		performSegue(withIdentifier: "showGraphs", sender: sender)
		
	}
	
	
	func sortRecords(_ _records: [Report]) -> [[Report]]? {
		
		/*
		Group the FHIR Observation resources as per their identifiers for charting
		
		*/
        let filtered = _records.filter({
			
			// Identifier is the `code` found; the top item in the array
			$0.rp_code != nil
				&&
				// Observation Value should be convertible to a `Double`
				Double($0.rp_observation ?? "") != nil
		})
		
		guard filtered.count > 0 else { return nil }
	
		let arranged = filtered.reduce(into: [:]) { dict, report in
			dict[report.rp_code!.code!.string, default: [Report]()].append(report)
		}
		
		return Array(arranged.values)
	}
}
