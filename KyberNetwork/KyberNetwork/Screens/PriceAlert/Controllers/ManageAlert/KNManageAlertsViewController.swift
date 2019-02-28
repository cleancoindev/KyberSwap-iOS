// Copyright SIX DAY LLC. All rights reserved.

import UIKit

protocol KNManageAlertsViewControllerDelegate: class {
  func manageAlertsViewControllerShouldBack()
  func manageAlertsViewControllerAddNewAlert()
  func manageAlertsViewControllerRunEvent(_ event: KNAlertTableViewEvent)
}

class KNManageAlertsViewController: KNBaseViewController {

  @IBOutlet weak var headerContainerView: UIView!
  @IBOutlet weak var navTitleLabel: UILabel!

  @IBOutlet weak var alertTableView: KNAlertTableView!
  @IBOutlet weak var bottomPaddingConstraintForAlertTableView: NSLayoutConstraint!

  @IBOutlet weak var emptyStateContainerView: UIView!
  @IBOutlet weak var emptyAlertDescLabel: UILabel!
  @IBOutlet weak var addAlertButton: UIButton!

  weak var delegate: KNManageAlertsViewControllerDelegate?

  override func viewDidLoad() {
    super.viewDidLoad()
    self.headerContainerView.applyGradient(with: UIColor.Kyber.headerColors)
    self.addAlertButton.applyGradient()

    let alerts = KNAlertStorage.shared.alerts
    self.alertTableView.delegate = self
    self.alertTableView.updateView(
      with: alerts,
      isFull: true
    )
    self.alertTableView.updateScrolling(isEnabled: true)
    self.navTitleLabel.text = "Price Alerts".toBeLocalised()
    self.emptyAlertDescLabel.text = "We will send you notifications when prices go above or below your targets".toBeLocalised()

    self.alertTableView.isHidden = alerts.isEmpty
    self.emptyStateContainerView.isHidden = !alerts.isEmpty
    self.addAlertButton.rounded(radius: KNAppStyleType.current.buttonRadius(for: self.addAlertButton.frame.height))
    self.addAlertButton.applyGradient()
    self.addAlertButton.setTitle(
      "Add Alert".toBeLocalised(),
      for: .normal
    )
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    self.bottomPaddingConstraintForAlertTableView.constant = self.bottomPaddingSafeArea()
    let alerts = KNAlertStorage.shared.alerts
    self.alertTableView.updateView(with: alerts, isFull: true)
    self.emptyStateContainerView.isHidden = !alerts.isEmpty
    self.alertTableView.isHidden = alerts.isEmpty
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.headerContainerView.removeSublayer(at: 0)
    self.headerContainerView.applyGradient(with: UIColor.Kyber.headerColors)
    self.addAlertButton.removeSublayer(at: 0)
    self.addAlertButton.applyGradient()
  }

  @IBAction func screenEdgePanAction(_ sender: UIScreenEdgePanGestureRecognizer) {
    if sender.state == .ended {
      KNCrashlyticsUtil.logCustomEvent(withName: "manage_alert", customAttributes: ["type": "screen_edge_pan_back"])
      self.delegate?.manageAlertsViewControllerShouldBack()
    }
  }

  @IBAction func backButtonPressed(_ sender: Any) {
    KNCrashlyticsUtil.logCustomEvent(withName: "manage_alert", customAttributes: ["type": "back_button_pressed"])
    self.delegate?.manageAlertsViewControllerShouldBack()
  }

  @IBAction func addAlertButtonPressed(_ sender: Any) {
    KNCrashlyticsUtil.logCustomEvent(withName: "manage_alert", customAttributes: ["type": "add_alert_button_pressed"])
    self.delegate?.manageAlertsViewControllerAddNewAlert()
  }
}

extension KNManageAlertsViewController: KNAlertTableViewDelegate {
  func alertTableView(_ tableView: UITableView, run event: KNAlertTableViewEvent) {
    switch event {
    case .update:
      let alerts = KNAlertStorage.shared.alerts
      self.emptyStateContainerView.isHidden = !alerts.isEmpty
      self.alertTableView.isHidden = alerts.isEmpty
    default:
      self.delegate?.manageAlertsViewControllerRunEvent(event)
    }
  }
}
