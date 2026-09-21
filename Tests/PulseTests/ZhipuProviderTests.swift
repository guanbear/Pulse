import Testing
@testable import Pulse

struct ZhipuProviderTests {
    @MainActor
    @Test
    func codingPlanUsesBigModelMark() {
        #expect(Provider.glmCoding.iconResource == "bigmodel")
        #expect(LobeIconStore.image(named: Provider.glmCoding.iconResource) != nil)
    }
}
