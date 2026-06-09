import Foundation

@MainActor
protocol StatusSymbolRefreshing: AnyObject {
    func refreshSymbol()
}

@MainActor
struct AppLaunchRefresher {
    private let viewModel: AppShellViewModel
    private let statusSymbolRefresher: any StatusSymbolRefreshing

    init(
        viewModel: AppShellViewModel,
        statusSymbolRefresher: any StatusSymbolRefreshing
    ) {
        self.viewModel = viewModel
        self.statusSymbolRefresher = statusSymbolRefresher
    }

    func refreshAfterLaunch() async {
        await viewModel.refresh()
        statusSymbolRefresher.refreshSymbol()
    }
}
