// Copyright SIX DAY LLC. All rights reserved.

import RealmSwift
import TrustKeystore
import TrustCore
import BigInt

class KNTrackerRateStorage {

  static var shared = KNTrackerRateStorage()
  private(set) var realm: Realm!

  init() {
    let config = RealmConfiguration.globalConfiguration()
    self.realm = try! Realm(configuration: config)
  }

  var rates: [KNTrackerRate] {
    return self.realm.objects(KNTrackerRate.self)
      .sorted(byKeyPath: "tokenAddress", ascending: true)
      .filter { !$0.tokenAddress.isEmpty }
  }

  func get(forPrimaryKey key: String) -> KNTrackerRate? {
    return self.realm.object(ofType: KNTrackerRate.self, forPrimaryKey: key)
  }

  func add(rates: [KNTrackerRate]) {
    self.realm.beginWrite()
    self.realm.add(rates, update: true)
    try!self.realm.commitWrite()
  }

  func update(rates: [KNTrackerRate]) {
    self.add(rates: rates)
  }

  func updateRates(from ieos: [IEOObject]) {
    let trackerRates = ieos.map({ return KNTrackerRate(ieoObject: $0) })
    self.update(rates: trackerRates)
  }

  func delete(rates: [KNTrackerRate]) {
    self.realm.beginWrite()
    self.realm.delete(rates)
    try! self.realm.commitWrite()
  }

  func deleteAll() {
    try! realm.write {
      realm.delete(realm.objects(KNTrackerRate.self))
    }
  }
}

extension KNTrackerRateStorage {
  func trackerRate(for token: TokenObject) -> KNTrackerRate? {
    return self.rates.first(where: { $0.isTrackerRate(for: token) })
  }
}