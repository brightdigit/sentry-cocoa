import XCTest

class SentryCrashReportTests: XCTestCase {
    
    private class Fixture {
        let testPath = "\(NSTemporaryDirectory())/SentryTest"
        let reportPath: String
        
        init() {
            reportPath = "\(self.testPath)SentryCrashReport.json"
        }
    }
    
    private let fixture = Fixture()
    private let fileManager = FileManager.default
    
    override func setUp() {
        super.setUp()
        deleteTestDir()
    }
    
    override func tearDown() {
        super.tearDown()
        deleteTestDir()
    }
        
    func testScopeInCrashReport_IsSameAsSerializingIt() throws {
        let sut = SentryCrashScopeObserver(maxBreadcrumbs: 10)
        let scope = TestData.scopeWith(observer: sut)
        
        serializeToCrashReport(scope: scope)

        writeCrashReport()
        
        let crashReportContents = FileManager.default.contents(atPath: fixture.reportPath) ?? Data()
        let crashReport: CrashReport = try! JSONDecoder().decode(CrashReport.self, from: crashReportContents)
        
        // The serialized scope is stored in user. This was the way to store the scope before declaring an extra area for it.
        // We compare the approach before with the current approach to make sure it's working fine.
        XCTAssertEqual(crashReport.user, crashReport.sentry_sdk_scope)
    }
    
    private func writeCrashReport() {
        var monitorContext = SentryCrash_MonitorContext()
        
        let api = sentrycrashcm_system_getAPI()
        api?.pointee.addContextualInfoToEvent(&monitorContext)
        
        sentrycrashreport_writeStandardReport(&monitorContext, fixture.reportPath)
    }
    
    /**
     * UserInfo is picked up by the crash report when writing a new report.
     */
    private func serializeToCrashReport(scope: Scope) {
        SentryCrash.sharedInstance().userInfo = scope.serialize()
    }
    
    private func deleteTestDir() {
        do {
            try fileManager.removeItem(atPath: fixture.testPath)
        } catch {
            // ignore
        }
    }
    
    struct CrashReport: Decodable {
        let user: CrashReportUserInfo
        let sentry_sdk_scope: CrashReportUserInfo
    }

    struct CrashReportUserInfo: Decodable, Equatable {
        let user: CrashReportUser
        let dist: String
        let context: [String: [String: Int]]
        let environment: String
        let tags: [String: String]
        let extra: [String: String]
        let fingerprint: [String]
        let level: String
        let breadcrumbs: [CrashReportCrumb]
    }

    struct CrashReportUser: Decodable, Equatable {
        let id: String
        let email: String
        let username: String
        let ip_address: String
        let data: [String: [String: String]]
    }

    struct CrashReportCrumb: Decodable, Equatable {
        let category: String
        let data: [String: [String: String]]
        let level: String
        let message: String
        let timestamp: String
        let type: String
    }
}
