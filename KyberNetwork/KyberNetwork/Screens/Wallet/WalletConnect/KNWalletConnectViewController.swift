// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import WalletConnect
import BigInt

class KNWalletConnectViewController: KNBaseViewController {

  let clientMeta = WCPeerMeta(name: "WalletConnect SDK", url: "https://github.com/TrustWallet/wallet-connect-swift")
  let wcSession: WCSession
  let knSession: KNSession
  fileprivate var interactor: WCInteractor?
  var recoverSession: Bool = false

  private var backgroundTaskId: UIBackgroundTaskIdentifier?
  private weak var backgroundTimer: Timer?

  @IBOutlet weak var headerContainerView: UIView!
  @IBOutlet weak var logoImageView: UIImageView!
  @IBOutlet weak var nameTextLabel: UILabel!
  @IBOutlet weak var connectionStatusLabel: UILabel!

  @IBOutlet weak var connectedToTextLabel: UILabel!
  @IBOutlet weak var urlLabel: UILabel!
  @IBOutlet weak var addressTextLabel: UILabel!
  @IBOutlet weak var addressLabel: UILabel!

  init(wcSession: WCSession, knSession: KNSession) {
    self.wcSession = wcSession
    self.knSession = knSession
    super.init(nibName: KNWalletConnectViewController.className, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.headerContainerView.applyGradient(with: UIColor.Kyber.headerColors)
    let address = self.knSession.wallet.address.description
    self.addressLabel.text = "\(address.prefix(12))...\(address.suffix(10))"
    self.urlLabel.text = ""
    self.connect(session: self.wcSession)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.headerContainerView.removeSublayer(at: 0)
    self.headerContainerView.applyGradient(with: UIColor.Kyber.headerColors)
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    self.interactor?.killSession().cauterize()
  }

  func connect(session: WCSession) {
    let interactor = WCInteractor(session: self.wcSession, meta: self.clientMeta, uuid: UIDevice.current.identifierForVendor ?? UUID())
    if interactor.state == .connected { interactor.disconnect() }
    let accounts = [self.knSession.wallet.address.description]
    let chainId = KNEnvironment.default.chainID

    interactor.killSession().cauterize()

    interactor.onError = { [weak self] error in
      self?.displayError(error: error)
    }

    interactor.onSessionRequest = { [weak self] (id, peerParam) in
      let peer = peerParam.peerMeta
      let message = [peer.description, peer.url].joined(separator: "\n")
      self?.nameTextLabel.text = peer.name
      self?.urlLabel.text = peer.url
      self?.logoImageView.setImage(with: peer.icons.first ?? "", placeholder: nil)
      let alert = UIAlertController(title: peer.name, message: message, preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "Reject", style: .destructive, handler: { _ in
          self?.interactor?.rejectSession().cauterize()
      }))
      alert.addAction(UIAlertAction(title: "Approve", style: .default, handler: { _ in
          self?.interactor?.approveSession(accounts: accounts, chainId: chainId).cauterize()
      }))
      self?.show(alert, sender: nil)
    }

    interactor.onDisconnect = { [weak self] (error) in
      if let error = error {
        self?.displayError(error: error)
      }
      self?.connectionStatusUpdated(false)
    }

    interactor.eth.onSign = { [weak self] (id, payload) in
      let alert = UIAlertController(title: "Sign data".toBeLocalised(), message: payload.message, preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { _ in
          self?.interactor?.rejectRequest(id: id, message: "User canceled").cauterize()
      }))
      alert.addAction(UIAlertAction(title: "Sign", style: .default, handler: { _ in
          self?.signEth(id: id, payload: payload)
      }))
      self?.present(alert, animated: true, completion: nil)
    }

    interactor.eth.onTransaction = { [weak self] (id, event, transaction) in
      let data = try! JSONEncoder().encode(transaction)
      self?.sendTransaction(id, data: data)
    }

    interactor.connect().done { [weak self] connected in
      self?.connectionStatusUpdated(connected)
    }.catch { [weak self] error in
      self?.displayError(error: error)
    }

    self.interactor = interactor
  }

  fileprivate func sendTransaction(_ id: Int64, data: Data) {
    guard let jsonData = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? JSONDictionary, let json = jsonData else {
      return
    }
    guard let from = json["from"] as? String, let to = json["to"] as? String,
      let value = (json["value"] as? String ?? "").fullBigInt(decimals: 0),
      from.lowercased() == self.knSession.wallet.address.description.lowercased() else {
      return
    }

    let message: String = {
      if let networkProxy = KNEnvironment.default.knCustomRPC?.networkAddress.lowercased(),
        networkProxy == to.lowercased() {
        return "Interact with Kyber Network Proxy: transfer \(value.string(decimals: 18, minFractionDigits: 0, maxFractionDigits: 6)) ETH to \(to). Please check your transaction details carefully."
      }
      if let token = KNSupportedTokenStorage.shared.supportedTokens.first(where: { return $0.contract.lowercased() == to.lowercased() }) {
        if value.isZero { return "Interact with \(token.symbol) contract. Please check your transaction details carefully." }
        return "Interact with \(token.symbol): transfer \(value.string(decimals: 18, minFractionDigits: 0, maxFractionDigits: 6)) ETH to \(to). Please check your transaction details carefully."
      }
      return "Transfer \(value.string(decimals: 18, minFractionDigits: 0, maxFractionDigits: 6)) ETH to \(to). Please check your transaction details carefully."
    }()
    let alert = UIAlertController(title: "Approve transaction", message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Reject", style: .destructive, handler: { _ in
      self.interactor?.rejectRequest(id: id, message: "").cauterize()
    }))
    alert.addAction(UIAlertAction(title: "Approve", style: .default, handler: { _ in
      self.displayLoading(text: "Submitting...", animated: true)
      self.knSession.externalProvider.sendTxWalletConnect(txData: json) { [weak self] result in
        guard let `self` = self else { return }
        self.hideLoading()
        switch result {
        case .success(let txHash):
          if let txID = txHash {
            self.interactor?.approveRequest(id: id, result: txID).cauterize()
            let tx = Transaction.getTransactionFromJsonWalletConnect(
              json: json,
              hash: txID,
              nonce: self.knSession.externalProvider.minTxCount - 1
            )
            self.knSession.addNewPendingTransaction(tx)
            self.showTopBannerView(with: "Broadcasted", message: "Your transaction has been broadcasted successfully!", time: 2.0) {
              self.openSafari(with: KNEnvironment.default.etherScanIOURLString + "tx/\(txID)")
            }
          } else {
            self.interactor?.rejectRequest(id: id, message: "Something went wrong, please try again").cauterize()
            self.showTopBannerView(with: "Error", message: "Something went wrong, please try again", time: 1.5)
          }
        case .failure(let error):
          self.interactor?.rejectRequest(id: id, message: error.prettyError).cauterize()
          self.displayError(error: error)
        }
      }
    }))
    self.present(alert, animated: true, completion: nil)
  }

  func approve(accounts: [String], chainId: Int) {
    self.interactor?.approveSession(accounts: accounts, chainId: chainId).done {
      print("<== approveSession done")
    }.catch { [weak self] error in
      self?.displayError(error: error)
    }
  }

  func signEth(id: Int64, payload: WCEthereumSignPayload) {
    let signData: Data = {
        switch payload {
        case .sign(let data, _):
            return data
        case .personalSign(let data, _):
            let prefix = "\u{19}Ethereum Signed Message:\n\(data.count)".data(using: .utf8)!
            return prefix + data
        case .signTypeData(_, let data, _):
            return data
        }
    }()
    if case .real(let account) = self.knSession.wallet.type {
      self.displayLoading(text: "Signing...", animated: true)
      let result = self.knSession.keystore.signMessage(signData, for: account)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        self.hideLoading()
        switch result {
        case .success(let data):
          self.interactor?.approveRequest(id: id, result: data.hexEncoded).cauterize()
        case .failure(let error):
          self.interactor?.rejectRequest(id: id, message: error.prettyError).cauterize()
          self.displayError(error: error)
        }
      }
    }
  }

  func connectionStatusUpdated(_ connected: Bool) {
    self.connectionStatusLabel.text = connected ? "Online" : "Offline"
    self.connectionStatusLabel.textColor = connected ? UIColor.Kyber.green : UIColor.Kyber.red
  }

  @IBAction func backButtonPressed(_ sender: Any) {
    let alert = UIAlertController(title: "Disconnect session?", message: "Do you want to disconnect this session?", preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    alert.addAction(UIAlertAction(title: "Disconnect", style: .default, handler: { _ in
      self.dismiss(animated: true, completion: nil)
    }))
    self.present(alert, animated: true, completion: nil)
  }
}

extension KNWalletConnectViewController {
  func applicationDidEnterBackground(_ application: UIApplication) {
    print("<== applicationDidEnterBackground")
    if self.interactor?.state != .connected { return }
    self.pauseInteractor()
  }

  func applicationWillEnterForeground(_ application: UIApplication) {
    print("==> applicationWillEnterForeground")
    if self.recoverSession {
      DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
        self.interactor?.resume()
      }
    }
  }

  func pauseInteractor() {
    self.recoverSession = true
    self.interactor?.pause()
  }
}