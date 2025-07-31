//
//  EcksteinDietAnalyticsView.swift
//  Eckstein
//
//  Created by Assistant on 14/07/2025.
//

import SwiftUI

struct EcksteinDietAnalyticsView: View {
    @StateObject private var viewModel = EcksteinDietViewModel()
    @StateObject private var bankManager = CalorieBankManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Performance Overview
                PerformanceOverviewCard(viewModel: viewModel)
                
                // Insights & Recommendations
                DietInsightsCard(viewModel: viewModel, bankManager: bankManager)
                
                // Visual Progress
                VisualProgressCard(viewModel: viewModel)
                
                // Calorie Bank Summary
                DietCalorieBankSummaryCard(bankManager: bankManager)
                
                // Consistency Score
                ConsistencyScoreCard(viewModel: viewModel)
                
                // Achievement Badges
                AchievementBadgesCard(viewModel: viewModel)
            }
            .padding()
        }
        .navigationTitle("your_progress".localized)
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Performance Overview Card
struct PerformanceOverviewCard: View {
    @ObservedObject var viewModel: EcksteinDietViewModel
    @State private var weeklyStats: EcksteinDietViewModel.WeeklyAnalytics?
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
                Text("this_weeks_performance".localized)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            if let stats = weeklyStats {
                // Performance Score
                let score = calculatePerformanceScore(stats)
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 20)
                            .frame(width: 150, height: 150)
                        
                        Circle()
                            .trim(from: 0, to: score / 100)
                            .stroke(
                                scoreGradient(score),
                                style: StrokeStyle(lineWidth: 20, lineCap: .round)
                            )
                            .frame(width: 150, height: 150)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 1), value: score)
                        
                        VStack {
                            Text("\(Int(score))")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                            Text("score".localized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(performanceMessage(score))
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(themeManager.accentColor.color)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                
                // Quick Stats
                HStack(spacing: 20) {
                    QuickStat(
                        icon: "checkmark.circle.fill",
                        value: "\(stats.compliantDays)",
                        label: "days_complete".localized,
                        color: .green
                    )
                    
                    QuickStat(
                        icon: "flame.fill",
                        value: "\(Int(stats.averageProteinGrams))",
                        label: "avg_protein".localized,
                        color: .orange
                    )
                    
                    QuickStat(
                        icon: "leaf.fill",
                        value: "\(Int(stats.averageCarbGrams))",
                        label: "avg_carbs".localized,
                        color: .green
                    )
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .onAppear {
            weeklyStats = viewModel.getWeeklyAnalytics()
        }
    }
    
    private func calculatePerformanceScore(_ stats: EcksteinDietViewModel.WeeklyAnalytics) -> Double {
        let proteinScore = min(100, (Double(stats.averageProteinGrams) / Double(stats.proteinTarget)) * 100)
        let carbScore = min(100, (Double(stats.averageCarbGrams) / Double(stats.carbTarget)) * 100)
        let completionScore = (stats.meal1CompletionRate + stats.meal2CompletionRate) / 2 * 100
        
        return (proteinScore + carbScore + completionScore) / 3
    }
    
    private func scoreGradient(_ score: Double) -> LinearGradient {
        if score >= 80 {
            return LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if score >= 60 {
            return LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            return LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private func performanceMessage(_ score: Double) -> String {
        if score >= 90 {
            return "outstanding_keep_it_up".localized
        } else if score >= 80 {
            return "great_job_doing_well".localized
        } else if score >= 70 {
            return "good_progress_room_improve".localized
        } else if score >= 60 {
            return "on_track_stay_focused".localized
        } else {
            return "lets_get_back_on_track".localized
        }
    }
}

struct QuickStat: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Insights Card
struct DietInsightsCard: View {
    @ObservedObject var viewModel: EcksteinDietViewModel
    @ObservedObject var bankManager: CalorieBankManager
    @State private var insights: [Insight] = []
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private func colorForInsightType(_ type: Insight.InsightType) -> Color {
        switch type {
        case .positive: return .green
        case .improvement: return .orange
        case .tip: return themeManager.dietPrimaryColor
        }
    }
    
    struct Insight {
        let icon: String
        let message: String
        let type: InsightType
        
        enum InsightType {
            case positive, improvement, tip
            
            var color: Color {
                switch self {
                case .positive: return .green
                case .improvement: return .orange
                case .tip: return .blue
                }
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("insights_and_tips".localized)
                    .font(.headline)
            }
            
            
            VStack(spacing: 12) {
                ForEach(insights.indices, id: \.self) { index in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: insights[index].icon)
                            .font(.title3)
                            .foregroundColor(colorForInsightType(insights[index].type))
                            .frame(width: 30)
                        
                        Text(insights[index].message)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(colorForInsightType(insights[index].type).opacity(0.1))
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .onAppear {
            generateInsights()
        }
    }
    
    private func generateInsights() {
        var newInsights: [Insight] = []
        
        let stats = viewModel.getWeeklyAnalytics()
            // Protein insights
            if stats.averageProteinGrams >= stats.proteinTarget {
                newInsights.append(Insight(
                    icon: "checkmark.circle.fill",
                    message: "excellent_protein_intake".localized,
                    type: .positive
                ))
            } else if stats.averageProteinGrams >= Int(Double(stats.proteinTarget) * 0.8) {
                newInsights.append(Insight(
                    icon: "arrow.up.circle",
                    message: String(format: "protein_intake_good_add_more".localized, stats.proteinTarget - stats.averageProteinGrams),
                    type: .improvement
                ))
            }
            
            // Calorie bank insights
            if bankManager.currentBalance > 1000 {
                newInsights.append(Insight(
                    icon: "building.columns.fill",
                    message: String(format: "great_calorie_savings".localized, bankManager.currentBalance),
                    type: .positive
                ))
            } else if bankManager.currentBalance < 300 {
                newInsights.append(Insight(
                    icon: "lightbulb",
                    message: String(format: "build_up_calorie_bank".localized, bankManager.currentBalance),
                    type: .tip
                ))
            }
            
            // Consistency insights
            if stats.meal2CompletionRate < 0.5 {
                newInsights.append(Insight(
                    icon: "clock",
                    message: "try_complete_meal_2_more".localized,
                    type: .improvement
                ))
            }
            
            // Food variety
            if stats.mostUsedProteins.count == 1 {
                newInsights.append(Insight(
                    icon: "arrow.triangle.2.circlepath",
                    message: "vary_protein_sources".localized,
                    type: .tip
                ))
            }
        
        insights = newInsights
    }
}

// MARK: - Visual Progress Card
struct VisualProgressCard: View {
    @ObservedObject var viewModel: EcksteinDietViewModel
    @State private var weeklyStats: EcksteinDietViewModel.WeeklyAnalytics?
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(themeManager.accentColor.color)
                Text("weekly_trends".localized)
                    .font(.headline)
            }
            
            if let stats = weeklyStats, !stats.dailyStats.isEmpty {
                // Visual bars for each day
                VStack(spacing: 12) {
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(stats.dailyStats, id: \.date) { day in
                            DayProgressBar(
                                dayStats: day,
                                proteinTarget: stats.proteinTarget,
                                carbTarget: stats.carbTarget
                            )
                        }
                    }
                    .frame(height: 150)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray5).opacity(0.5))
                    .cornerRadius(12)
                    
                    // Legend
                    HStack(spacing: 20) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 10, height: 10)
                            Text("protein".localized)
                                .font(.caption)
                        }
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 10, height: 10)
                            Text("carbs".localized)
                                .font(.caption)
                        }
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(themeManager.dietPrimaryColor)
                                .frame(width: 10, height: 10)
                            Text("complete".localized)
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            } else {
                Text("start_tracking_see_progress".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .onAppear {
            weeklyStats = viewModel.getWeeklyAnalytics()
        }
    }
}

struct DayProgressBar: View {
    let dayStats: EcksteinDietViewModel.DailyMealStats
    let proteinTarget: Int
    let carbTarget: Int
    
    private var proteinPercentage: Double {
        Double(dayStats.proteinGrams) / Double(proteinTarget)
    }
    
    private var carbPercentage: Double {
        Double(dayStats.carbGrams) / Double(carbTarget)
    }
    
    private var isComplete: Bool {
        dayStats.meal1Complete && dayStats.meal2Complete
    }
    
    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                    
                    // Stacked bars from bottom
                    VStack(spacing: 1) {
                        Spacer()
                        
                        // Orange protein bar at bottom
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.orange)
                            .frame(height: min(geometry.size.height * 0.4, max(5, geometry.size.height * 0.4 * min(proteinPercentage, 1.0))))
                        
                        // Green carbs bar on top of protein
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.green)
                            .frame(height: min(geometry.size.height * 0.4, max(5, geometry.size.height * 0.4 * min(carbPercentage, 1.0))))
                        
                        // Blue complete indicator at top if both meals done
                        if isComplete {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(ThemeManager.shared.dietPrimaryColor)
                                .frame(height: 8)
                        }
                    }
                    .frame(height: geometry.size.height)
                }
            }
            
            Text(dayLabel(for: dayStats.date))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1))
    }
}

// MARK: - Calorie Bank Summary Card
struct DietCalorieBankSummaryCard: View {
    @ObservedObject var bankManager: CalorieBankManager
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "building.columns.fill")
                    .foregroundColor(themeManager.accentColor.color)
                Text("calorie_bank_summary".localized)
                    .font(.headline)
            }
            
            HStack(spacing: 20) {
                // Current Balance
                VStack(alignment: .leading, spacing: 8) {
                    Text("saved".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(bankManager.currentBalance)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.accentColor.color)
                    
                    Text("calories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                    .frame(height: 50)
                
                // Today's Activity
                VStack(alignment: .leading, spacing: 8) {
                    Text("today".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(bankManager.todayAvailable)")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                            Text("available")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(bankManager.todayUsed)")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                            Text("used")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Savings Potential
            let potentialSavings = calculatePotentialSavings()
            if potentialSavings > 0 {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.yellow)
                    Text(String(format: "could_save_more_calories".localized, potentialSavings))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .onAppear {
            bankManager.loadCurrentBalance()
        }
    }
    
    private func calculatePotentialSavings() -> Int {
        // Calculate based on unused daily allowance (150 calories per day)
        // If user is not using full daily allowance, show potential savings
        let dailyAllowance = 150
        let daysRemaining = 7 // Always show weekly potential
        
        // Calculate how much the user typically saves per day
        let todayUnused = max(0, dailyAllowance - bankManager.todayUsed)
        
        // Assume user could save at least half of unused daily calories
        let potentialDailySaving = todayUnused > 0 ? todayUnused / 2 : dailyAllowance / 3
        
        return potentialDailySaving * daysRemaining
    }
}

// MARK: - Consistency Score Card
struct ConsistencyScoreCard: View {
    @ObservedObject var viewModel: EcksteinDietViewModel
    @State private var complianceStats: EcksteinDietViewModel.ComplianceStats?
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.purple)
                Text("consistency_score".localized)
                    .font(.headline)
            }
            
            if let stats = complianceStats {
                HStack(spacing: 30) {
                    // Current Streak
                    VStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .font(.title)
                            .foregroundColor(stats.currentStreak > 0 ? .orange : .gray)
                        
                        Text("\(stats.currentStreak)")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("current_streak".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                        .frame(height: 60)
                    
                    // Best Streak
                    VStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.title)
                            .foregroundColor(.yellow)
                        
                        Text("\(stats.longestStreak)")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("best_streak".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                        .frame(height: 60)
                    
                    // Compliance Rate
                    VStack(spacing: 8) {
                        Image(systemName: "percent")
                            .font(.title)
                            .foregroundColor(themeManager.accentColor.color)
                        
                        Text("\(Int(stats.complianceRate * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("compliance".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                
                if stats.currentStreak > 0 {
                    Text(motivationalMessage(for: stats.currentStreak))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(themeManager.accentColor.color)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 100)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .onAppear {
            complianceStats = viewModel.getComplianceStats()
        }
    }
    
    private func motivationalMessage(for streak: Int) -> String {
        switch streak {
        case 1: return "great_start_keep_going".localized
        case 2...3: return "building_momentum".localized
        case 4...6: return "excellent_consistency".localized
        case 7...13: return "one_week_strong".localized
        case 14...20: return "two_weeks_unstoppable".localized
        case 21...29: return "three_weeks_habit_formed".localized
        default: return String(format: "incredible_dedication_days".localized, streak)
        }
    }
}

// MARK: - Achievement Badges Card
struct AchievementBadgesCard: View {
    @ObservedObject var viewModel: EcksteinDietViewModel
    @StateObject private var achievementManager = AchievementManager.shared
    @State private var selectedAchievement: Achievement?
    @State private var showingDetail = false
    @State private var showingAllAchievements = false
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "rosette")
                    .foregroundColor(.purple)
                Text("achievements".localized)
                    .font(.headline)
                
                Spacer()
                
                Text("\(achievementManager.achievements.filter { $0.isEarned }.count)/\(achievementManager.achievements.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Show first 9 achievements in grid, with "View All" if there are more
            let displayAchievements = Array(achievementManager.achievements.prefix(9))
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(displayAchievements) { achievement in
                    BadgeView(
                        achievement: achievement,
                        progress: achievementManager.getProgress(for: achievement.id)
                    )
                    .onTapGesture {
                        selectedAchievement = achievement
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showingDetail = true
                        }
                    }
                }
                
                if achievementManager.achievements.count > 9 {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 60, height: 60)
                            
                            Text("+\(achievementManager.achievements.count - 9)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                        }
                        
                        Text("view_all".localized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                    }
                    .onTapGesture {
                        showingAllAchievements = true
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .onAppear {
            // Check for new achievements
            achievementManager.checkForNewAchievements(
                dietViewModel: viewModel,
                bankManager: CalorieBankManager.shared
            )
        }
        .sheet(isPresented: $showingDetail) {
            if let achievement = selectedAchievement {
                AchievementDetailView(
                    achievement: achievement,
                    progress: achievementManager.getProgress(for: achievement.id)
                )
            }
        }
        .sheet(isPresented: $showingAllAchievements) {
            AllAchievementsView(achievementManager: achievementManager)
        }
    }
}

struct BadgeView: View {
    let achievement: Achievement
    let progress: (current: Int, required: Int)?
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(achievement.isEarned ? achievement.displayColor.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                if !achievement.isEarned, let progress = progress {
                    // Progress ring for unearned achievements
                    Circle()
                        .trim(from: 0, to: CGFloat(progress.current) / CGFloat(progress.required))
                        .stroke(
                            achievement.displayColor.opacity(0.5),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                }
                
                Image(systemName: achievement.isEarned ? achievement.icon : "lock.fill")
                    .font(.title2)
                    .foregroundColor(achievement.isEarned ? achievement.displayColor : .gray)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
            }
            
            Text(achievement.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(achievement.isEarned ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .opacity(achievement.isEarned ? 1.0 : 0.6)
        .onAppear {
            if achievement.isEarned {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
    }
}