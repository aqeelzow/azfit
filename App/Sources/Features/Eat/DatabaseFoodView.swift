import AZModel
import AZSync
import SwiftUI

/// A search match from the food database: reads its full label, then shows it for logging.
struct DatabaseFoodView: View {
    let hit: FoodDatabase.Hit
    let slot: Meal.Slot

    @Environment(AppEnvironment.self) private var environment
    @State private var food: Food?
    @State private var problem: String?

    var body: some View {
        if let food {
            FoodDetailView(food: food, slot: slot)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                TopBar(title: "", subtitle: nil) {
                    BackButton()
                } trailing: {
                    Color.clear.frame(width: 44, height: 44)
                }
                VStack(alignment: .leading, spacing: 8) {
                    if let brand = hit.brand { SectionLabel(text: brand) }
                    Text(hit.name).font(.az(30, .heavy)).tracking(-0.7)
                    if let problem {
                        Text(problem).font(.az(15)).foregroundStyle(AZColor.muted).padding(.top, 8)
                        PillButton(title: "Try again", systemImage: "arrow.clockwise", style: .fill) {
                            Task { await load() }
                        }
                        .padding(.top, 4)
                    } else {
                        ProgressView().padding(.top, 16)
                    }
                }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.top, 8)
                Spacer()
            }
            .azScreen()
            .task { await load() }
        }
    }

    private func load() async {
        problem = nil
        do {
            if let found = try await environment.foods.product(barcode: hit.code) {
                food = found
            } else {
                problem = "The database has no calories for this one. Pick another, or create it yourself."
            }
        } catch {
            problem = AddFoodView.message(error)
        }
    }
}
