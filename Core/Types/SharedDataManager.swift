//
//  SharedDataManager.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 5/30/25.
//


// MARK: - Shared Data Manager
final class SharedDataManager {
    // MARK: - Singleton
    static let shared = SharedDataManager()
    
    // MARK: - Constants
    private enum Keys {
        static let remainingBudget = "remainingBudget"
        static let monthlyBudget = "monthlyBudget"
        static let suiteName = "group.com.brandontitensor.BrandonsBudget"
    }
    
    // MARK: - Properties
    private let sharedDefaults: UserDefaults?
    
    // MARK: - Initialization
    private init() {
        sharedDefaults = UserDefaults(suiteName: Keys.suiteName)
    }
    
    // MARK: - Public Methods
    func setRemainingBudget(_ amount: Double) {
        sharedDefaults?.set(amount, forKey: Keys.remainingBudget)
    }
    
    func getRemainingBudget() -> Double {
        return sharedDefaults?.double(forKey: Keys.remainingBudget) ?? 0.0
    }
    
    func setMonthlyBudget(_ amount: Double) {
        sharedDefaults?.set(amount, forKey: Keys.monthlyBudget)
    }
    
    func getMonthlyBudget() -> Double {
        return sharedDefaults?.double(forKey: Keys.monthlyBudget) ?? 0.0
    }
    
    func resetData() {
        setRemainingBudget(0.0)
        setMonthlyBudget(0.0)
    }
}

// MARK: - Year Picker View
/// A reusable view for selecting years with validation and proper range handling
struct YearPickerView: View {
    // MARK: - Properties
    @Binding var selectedYear: Int
    let onDismiss: () -> Void
    let onYearSelected: (Int) -> Void
    
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Constants
    private let currentYear = Calendar.current.component(.year, from: Date())
    private let yearRange: ClosedRange<Int>
    
    // MARK: - Initialization
    init(
        selectedYear: Binding<Int>,
        onDismiss: @escaping () -> Void,
        onYearSelected: @escaping (Int) -> Void,
        numberOfPastYears: Int = 5,
        numberOfFutureYears: Int = 5
    ) {
        self._selectedYear = selectedYear
        self.onDismiss = onDismiss
        self.onYearSelected = onYearSelected
        
        // Calculate year range
        self.yearRange = (currentYear - numberOfPastYears)...(currentYear + numberOfFutureYears)
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(yearRange, id: \.self) { year in
                        yearRow(for: year)
                    }
                } footer: {
                    Text("Showing years from \(yearRange.lowerBound) to \(yearRange.upperBound)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Select Year")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Done") {
                    onYearSelected(selectedYear)
                    dismiss()
                }
            )
        }
    }
    
    // MARK: - View Components
    private func yearRow(for year: Int) -> some View {
        Button(action: { selectYear(year) }) {
            HStack {
                Text(String(year))
                    .foregroundColor(.primary)
                Spacer()
                if year == selectedYear {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
                if year == currentYear {
                    Text("Current")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(createAccessibilityLabel(for: year))
        .accessibilityAddTraits(year == selectedYear ? [.isSelected] : [])
    }
    
    // MARK: - Helper Methods
    private func selectYear(_ year: Int) {
        selectedYear = year
    }
    
    private func createAccessibilityLabel(for year: Int) -> String {
        var label = String(year)
        if year == currentYear {
            label += ", current year"
        }
        if year == selectedYear {
            label += ", selected"
        }
        return label
    }
}

// MARK: - Data Validation Utilities
public struct DataValidator {
    /// Validate a budget entry
    public static func validateBudgetEntry(_ entry: BudgetEntry) throws {
        if entry.amount <= 0 {
            throw ValidationError.invalidAmount("Amount must be greater than zero")
        }
        
        if entry.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.invalidCategory("Category cannot be empty")
        }
        
        if entry.date > Date() {
            throw ValidationError.invalidDate("Date cannot be in the future")
        }
        
        if entry.amount > AppConstants.Validation.maximumTransactionAmount {
            throw ValidationError.invalidAmount("Amount exceeds maximum allowed")
        }
    }
    
    /// Validate a monthly budget
    public static func validateMonthlyBudget(_ budget: MonthlyBudget) throws {
        if budget.amount < 0 {
            throw ValidationError.invalidAmount("Budget amount cannot be negative")
        }
        
        if budget.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.invalidCategory("Category cannot be empty")
        }
        
        if budget.month < 1 || budget.month > 12 {
            throw ValidationError.invalidDate("Month must be between 1 and 12")
        }
        
        if budget.year < 1900 || budget.year > 9999 {
            throw ValidationError.invalidDate("Invalid year")
        }
    }
    
    /// Validation error types
    public enum ValidationError: LocalizedError {
        case invalidAmount(String)
        case invalidCategory(String)
        case invalidDate(String)
        case invalidData(String)
        
        public var errorDescription: String? {
            switch self {
            case .invalidAmount(let message): return "Invalid amount: \(message)"
            case .invalidCategory(let message): return "Invalid category: \(message)"
            case .invalidDate(let message): return "Invalid date: \(message)"
            case .invalidData(let message): return "Invalid data: \(message)"
            }
        }
    }
}

