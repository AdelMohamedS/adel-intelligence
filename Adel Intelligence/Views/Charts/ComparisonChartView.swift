import Charts
import SwiftUI

struct ComparisonData: Identifiable {
    var id = UUID()
    var criterion: String
    var model: String
    var score: Double
}

// Chart type enum for selection
enum ComparisonChartType: String, CaseIterable, Identifiable {
    case bar = "Bar Chart"
    case radar = "Radar Chart"
    case line = "Line Chart"
    case pie = "Pie Chart"

    var id: String { self.rawValue }

    var systemImage: String {
        switch self {
        case .bar: return "chart.bar"
        case .radar: return "scope"
        case .line: return "chart.xyaxis.line"
        case .pie: return "chart.pie"
        }
    }
}

struct ComparisonChartView: View {
    var data: [ComparisonData] = []
    var criteria: [String] = []
    var models: [String] = []
    var orderedModels: [String] = []  // New property for ordered models
    @State private var parseError: String?
    @State private var originalJson: String = ""
    @State private var selectedChartType: ComparisonChartType = .bar

    // Predefined preferred model order
    private static let preferredModelOrder = ["ChatGPT", "Microsoft Copilot", "Google Gemini"]

    // Colors for the charts
    private let chartColors: [Color] = [.blue, .green, .red, .orange, .purple, .yellow, .pink]

    init(jsonString: String) {
        print("ComparisonChartView init with string of length: \(jsonString.count)")
        print("JSON string starts with: \(jsonString.prefix(100))")
        self.originalJson = jsonString

        // If the jsonString is empty, use sample data
        let inputJson = jsonString.isEmpty ? "USE_SAMPLE_DATA" : jsonString

        let parsedData = Self.parseComparisonData(from: inputJson)
        self.criteria = parsedData.criteria
        self.models = parsedData.models
        self.data = parsedData.data
        self._parseError = State(initialValue: parsedData.error)

        // Create ordered models list based on preferred order
        self.orderedModels = Self.getOrderedModels(from: self.models)

        // Debug: print parsing results
        print("Parsing complete. Error: \(parsedData.error ?? "None")")
        print("Found \(self.criteria.count) criteria: \(self.criteria)")
        print("Found \(self.models.count) models: \(self.models)")
        print("Ordered models: \(self.orderedModels)")
        print("Generated \(self.data.count) data points")
    }

    // Helper method to sort models in preferred order
    private static func getOrderedModels(from models: [String]) -> [String] {
        // Start with preferred models that exist in the input
        var result: [String] = []
        for model in preferredModelOrder {
            if models.contains(model) {
                result.append(model)
            }
        }

        // Add any remaining models (not in preferred order) at the end
        for model in models {
            if !result.contains(model) {
                result.append(model)
            }
        }

        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let error = parseError {
                VStack(alignment: .leading) {
                    Text("Error parsing JSON:")
                        .foregroundColor(.red)
                        .bold()
                    Text(error)
                        .foregroundColor(.red)

                    Spacer().frame(height: 10)

                    Text("Try using the Test Chart button to generate sample data.")
                }
                .padding()
                .background(Color(.textBackgroundColor))
                .cornerRadius(8)
            } else if data.isEmpty {
                Text("No comparison data available")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                // Chart type picker
                Picker("Chart Type", selection: $selectedChartType) {
                    ForEach(ComparisonChartType.allCases) { chartType in
                        Label(chartType.rawValue, systemImage: chartType.systemImage)
                            .tag(chartType)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 8)

                ScrollView {
                    VStack(spacing: 20) {
                        // Current chart based on selection
                        VStack(alignment: .leading) {
                            Text("Comparison Chart: \(selectedChartType.rawValue)")
                                .font(.headline)
                                .padding(.bottom, 5)

                            switch selectedChartType {
                            case .bar:
                                barChartView
                            case .radar:
                                radarChartView
                            case .line:
                                lineChartView
                            case .pie:
                                pieChartViewContainer
                            }
                        }

                        Divider()

                        // Model comparison table
                        VStack(alignment: .leading) {
                            Text("Comparison Table")
                                .font(.headline)
                                .padding(.bottom, 5)

                            comparisonTable
                        }
                    }
                    .padding()
                }
                .background(Color(.textBackgroundColor))
                .cornerRadius(8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    private var barChartView: some View {
        let sortedData = getSortedChartData()

        return Chart {
            ForEach(sortedData) { item in
                BarMark(
                    x: .value("Score", item.score),
                    y: .value("Model & Criterion", "\(item.model): \(item.criterion)")
                )
                .foregroundStyle(by: .value("Model", item.model))
                .annotation(position: .trailing) {
                    Text(String(format: "%.1f", item.score))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .chartLegend(position: .top)
        .frame(height: CGFloat(max(data.count * 15, 300)))
        .padding(.vertical)
    }

    // Radar/Spider Chart
    private var radarChartView: some View {
        VStack {
            // We'll create one radar chart per model
            ForEach(orderedModels, id: \.self) { model in
                VStack(alignment: .leading) {
                    Text(model)
                        .font(.headline)
                        .padding(.top, 10)

                    ZStack {
                        // Background spider web
                        ForEach(0..<5) { level in
                            createPolygon(sides: criteria.count, insetFraction: CGFloat(level) / 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        }

                        // Data polygon
                        let modelScores = getScoresForModel(model)
                        createDataPolygon(
                            sides: criteria.count,
                            values: modelScores
                        )
                        .fill(getColorForModel(model).opacity(0.2))

                        createDataPolygon(
                            sides: criteria.count,
                            values: modelScores
                        )
                        .stroke(getColorForModel(model), lineWidth: 2)

                        // Criteria labels and data points - now properly aligned
                        ForEach(0..<criteria.count, id: \.self) { i in
                            let angle =
                                2 * Double.pi * Double(i) / Double(criteria.count) - Double.pi / 2
                            let labelDistance: CGFloat = 1.15  // Distance for the label outside the chart
                            let labelX = 110 + 110 * CGFloat(cos(angle)) * labelDistance
                            let labelY = 110 + 110 * CGFloat(sin(angle)) * labelDistance

                            // The value and point position (scaled by score)
                            let value = modelScores[i] / 10.0  // Assuming max score is 10
                            let pointX = 110 + 110 * CGFloat(cos(angle)) * CGFloat(value)
                            let pointY = 110 + 110 * CGFloat(sin(angle)) * CGFloat(value)

                            // Draw a line from point to edge
                            Path { path in
                                path.move(to: CGPoint(x: pointX, y: pointY))
                                path.addLine(
                                    to: CGPoint(
                                        x: 110 + 110 * CGFloat(cos(angle)),
                                        y: 110 + 110 * CGFloat(sin(angle))))
                            }
                            .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)

                            // Score dot with score value
                            ZStack {
                                Circle()
                                    .fill(getColorForModel(model))
                                    .frame(width: 8, height: 8)

                                Text(String(format: "%.1f", modelScores[i]))
                                    .font(.system(size: 8))
                                    .foregroundColor(.primary)
                                    .offset(x: 0, y: -14)
                            }
                            .position(x: pointX, y: pointY)

                            // Label with a smaller dot indicator
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(getColorForModel(model))
                                    .frame(width: 6, height: 6)

                                Text(criteria[i])
                                    .font(.caption2)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .fixedSize()
                            }
                            .position(x: labelX, y: labelY)
                        }
                    }
                    .frame(width: 250, height: 250)
                    .padding(.vertical, 10)
                }
                .padding(.bottom, 20)
                if model != orderedModels.last {
                    Divider()
                }
            }
        }
        .padding(.vertical)
    }

    // Line Chart - Improved implementation following Apple guidelines
    private var lineChartView: some View {
        Chart {
            ForEach(orderedModels, id: \.self) { model in
                let modelData = data.filter { $0.model == model }
                    .sorted { $0.criterion < $1.criterion }

                ForEach(Array(zip(modelData.indices, modelData)), id: \.0) { _, item in
                    LineMark(
                        x: .value("Criterion", item.criterion),
                        y: .value("Score", item.score)
                    )
                    .foregroundStyle(by: .value("Model", model))
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Criterion", item.criterion),
                        y: .value("Score", item.score)
                    )
                    .foregroundStyle(by: .value("Model", model))
                    .symbolSize(CGSize(width: 10, height: 10))
                    .annotation(position: .top, spacing: 5) {
                        Text(String(format: "%.1f", item.score))
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .chartYScale(domain: 0...10)
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisValueLabel {
                    if let stringValue = value.as(String.self),
                        criteria.contains(stringValue)
                    {
                        Text(stringValue)
                            .font(.caption)
                            .rotationEffect(.degrees(-45))
                            .frame(width: 60, alignment: .trailing)
                    }
                }
                AxisGridLine()
                AxisTick()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic) { value in
                AxisValueLabel()
                AxisGridLine()
            }
        }
        .chartLegend(position: .top, alignment: .center, spacing: 10)
        .frame(height: 350)
        .padding(.bottom, 30)  // Extra padding for rotated labels
    }

    // Pie Chart Container - We'll show one pie chart per criterion
    private var pieChartViewContainer: some View {
        VStack(spacing: 24) {
            ForEach(criteria, id: \.self) { criterion in
                VStack(alignment: .leading) {
                    Text(criterion)
                        .font(.headline)
                    pieChartFor(criterion: criterion)
                        .frame(height: 200)
                }
                if criterion != criteria.last {
                    Divider()
                }
            }
        }
    }

    // Individual Pie Chart for a criterion
    private func pieChartFor(criterion: String) -> some View {
        let criterionData = data.filter { $0.criterion == criterion }

        return Chart(criterionData) { item in
            SectorMark(
                angle: .value("Score", item.score),
                innerRadius: .ratio(0.5),
                angularInset: 1.5
            )
            .cornerRadius(3)
            .foregroundStyle(by: .value("Model", item.model))
            .annotation(position: .overlay) {
                Text(String(format: "%.1f", item.score))
                    .font(.caption)
                    .foregroundColor(.white)
                    .fontWeight(.bold)
            }
        }
        .chartLegend(position: .bottom)
    }

    // Helper method to sort chart data by model order and criteria
    private func getSortedChartData() -> [ComparisonData] {
        // Group data by model first, then by criterion
        var sortedData: [ComparisonData] = []

        // Go through models in the preferred order
        for model in orderedModels {
            // For each model, add all criteria
            for criterion in criteria {
                if let dataPoint = data.first(where: {
                    $0.model == model && $0.criterion == criterion
                }) {
                    sortedData.append(dataPoint)
                }
            }
        }

        return sortedData
    }

    private var comparisonTable: some View {
        VStack(alignment: .leading, spacing: 10) {
            Grid(alignment: .leading, horizontalSpacing: 15, verticalSpacing: 10) {
                // Header row
                GridRow {
                    Text("Criteria")
                        .bold()

                    ForEach(orderedModels, id: \.self) { model in
                        Text(model)
                            .bold()
                    }
                }
                .padding(.bottom, 5)

                Divider()

                // Data rows - one per criterion
                ForEach(criteria, id: \.self) { criterion in
                    GridRow {
                        Text(criterion)

                        ForEach(orderedModels, id: \.self) { model in
                            let score = scoreFor(model: model, criterion: criterion)
                            Text(String(format: "%.1f", score))
                        }
                    }

                    if criterion != criteria.last {
                        Divider()
                    }
                }
            }
        }
    }

    private func scoreFor(model: String, criterion: String) -> Double {
        if let dataPoint = data.first(where: { $0.model == model && $0.criterion == criterion }) {
            return dataPoint.score
        }
        return 0
    }

    // Helper functions for radar chart
    private func createPolygon(sides: Int, insetFraction: CGFloat) -> Path {
        Path { path in
            let center = CGPoint(x: 110, y: 110)
            let radius: CGFloat = 110 * (1 - insetFraction)

            for i in 0..<sides {
                let angle = 2 * Double.pi / Double(sides) * Double(i) - Double.pi / 2
                let x = center.x + radius * CGFloat(cos(angle))
                let y = center.y + radius * CGFloat(sin(angle))

                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.closeSubpath()
        }
    }

    private func createDataPolygon(sides: Int, values: [Double]) -> Path {
        Path { path in
            let center = CGPoint(x: 110, y: 110)
            let maxRadius: CGFloat = 110

            for i in 0..<sides {
                let angle = 2 * Double.pi / Double(sides) * Double(i) - Double.pi / 2
                let value = CGFloat(values[i]) / 10.0  // Assuming max score is 10
                let radius = maxRadius * value
                let x = center.x + radius * CGFloat(cos(angle))
                let y = center.y + radius * CGFloat(sin(angle))

                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.closeSubpath()
        }
    }

    private func getScoresForModel(_ model: String) -> [Double] {
        return criteria.map { criterion in
            scoreFor(model: model, criterion: criterion)
        }
    }

    private func getColorForModel(_ model: String) -> Color {
        let index = orderedModels.firstIndex(of: model) ?? 0
        return chartColors[index % chartColors.count]
    }

    // Improved JSON parsing with better error handling
    private static func parseComparisonData(from jsonString: String) -> (
        criteria: [String], models: [String], data: [ComparisonData], error: String?
    ) {
        print("========= COMPARISON DATA PARSING =========")
        print("Parsing JSON string of length: \(jsonString.count)")
        if jsonString.count > 0 {
            print("First 50 chars: \(jsonString.prefix(50))")
        }

        var criteria: [String] = []
        var models: [String] = []
        var comparisonData: [ComparisonData] = []

        // Handle empty input
        guard !jsonString.isEmpty else {
            print("Empty JSON string received")
            return (criteria, models, comparisonData, "Empty JSON string")
        }

        // Create hardcoded sample data if testing/debugging is needed
        if jsonString == "USE_SAMPLE_DATA" {
            print("Using SAMPLE DATA for chart")
            criteria = [
                "Accuracy", "Response Time", "Relevance", "User Satisfaction", "User Engagement",
            ]
            models = ["ChatGPT", "Microsoft Copilot", "Google Gemini"]

            let modelScores = [
                "ChatGPT": [8.0, 9.0, 9.0, 9.0, 9.0],
                "Microsoft Copilot": [7.0, 6.0, 6.0, 7.0, 6.0],
                "Google Gemini": [5.0, 8.0, 5.0, 5.0, 6.0],
            ]

            for model in models {
                if let scores = modelScores[model] {
                    for (index, score) in scores.enumerated() {
                        if index < criteria.count {
                            comparisonData.append(
                                ComparisonData(
                                    criterion: criteria[index],
                                    model: model,
                                    score: score
                                ))
                        }
                    }
                }
            }

            return (criteria, models, comparisonData, nil)
        }

        // Try to parse as JSON
        do {
            print("Attempting to extract JSON data")
            guard let jsonData = extractJsonData(from: jsonString) else {
                print("FAILED to extract JSON data")
                return (criteria, models, comparisonData, "Failed to extract valid JSON")
            }

            print("JSON data extracted, length: \(jsonData.count)")
            if let extractedJsonString = String(data: jsonData, encoding: .utf8) {
                print("Extracted JSON (first 100 chars): \(extractedJsonString.prefix(100))")
            }

            let json = try JSONSerialization.jsonObject(with: jsonData)
            print("JSON parsed successfully: \(type(of: json))")

            if let jsonDict = json as? [String: Any] {
                // Extract criteria
                if let criteriaArray = jsonDict["criteria"] as? [String] {
                    criteria = criteriaArray
                    print("Found criteria: \(criteria)")
                } else {
                    print("Missing or invalid criteria field")
                    return (criteria, models, comparisonData, "Missing or invalid 'criteria' field")
                }

                // Extract scores
                if let scores = jsonDict["scores"] as? [String: [Double]] {
                    models = Array(scores.keys)
                    print("Found models: \(models)")

                    for model in models {
                        if let modelScores = scores[model] {
                            print("Processing scores for \(model): \(modelScores)")
                            for (index, score) in modelScores.enumerated() {
                                if index < criteria.count {
                                    let dataPoint = ComparisonData(
                                        criterion: criteria[index],
                                        model: model,
                                        score: score
                                    )
                                    comparisonData.append(dataPoint)
                                }
                            }
                        }
                    }
                } else {
                    print("Missing or invalid scores field")
                    return (criteria, models, comparisonData, "Missing or invalid 'scores' field")
                }
            } else {
                print("JSON is not a dictionary")
                return (criteria, models, comparisonData, "JSON is not a dictionary")
            }
        } catch {
            let errorMessage = "JSON parsing error: \(error.localizedDescription)"
            print(errorMessage)
            return (criteria, models, comparisonData, errorMessage)
        }

        print("Successfully parsed comparison data: \(comparisonData.count) data points")
        return (criteria, models, comparisonData, nil)
    }

    // Helper method to extract valid JSON data from a string that might contain other text
    private static func extractJsonData(from string: String) -> Data? {
        print("ComparisonChartView processing string of length: \(string.count)")
        print("String starts with: \(string.prefix(50))")
        print("String contains ```json: \(string.contains("```json"))")
        print("String contains criteria: \(string.contains("\"criteria\""))")
        print("String contains scores: \(string.contains("\"scores\""))")

        // Don't process empty strings
        guard !string.isEmpty else {
            print("Empty string received in extractJsonData")
            return nil
        }

        // First priority: check if entire string is already valid JSON
        if string.hasPrefix("{") && string.contains("\"criteria\"") && string.contains("\"scores\"")
        {
            print("Using string as direct JSON - already in valid format")
            return string.data(using: .utf8)
        }

        // Second priority: try to find JSON within code blocks
        do {
            let jsonBlockPattern = "```json\\s*([\\s\\S]*?)\\s*```"
            let jsonBlockRegex = try NSRegularExpression(pattern: jsonBlockPattern)

            print("Searching for JSON code blocks with pattern: \(jsonBlockPattern)")

            let matches = jsonBlockRegex.matches(
                in: string, range: NSRange(string.startIndex..., in: string))
            print("Found \(matches.count) JSON code block matches")

            if let match = matches.first,
                let range = Range(match.range(at: 1), in: string)
            {
                let jsonString = String(string[range]).trimmingCharacters(
                    in: .whitespacesAndNewlines)
                print("Found JSON in code block, length: \(jsonString.count)")
                print("JSON from code block starts with: \(jsonString.prefix(50))")
                return jsonString.data(using: .utf8)
            }

            // Third priority: try to find raw JSON objects
            let jsonObjectPattern = "\\{[\\s\\S]*?\"criteria\"[\\s\\S]*?\"scores\"[\\s\\S]*?\\}"
            let jsonObjectRegex = try NSRegularExpression(pattern: jsonObjectPattern)

            let objectMatches = jsonObjectRegex.matches(
                in: string, range: NSRange(string.startIndex..., in: string))
            print("Found \(objectMatches.count) JSON object matches")

            if let match = objectMatches.first,
                let range = Range(match.range, in: string)
            {
                let jsonString = String(string[range]).trimmingCharacters(
                    in: .whitespacesAndNewlines)
                print("Found raw JSON object, length: \(jsonString.count)")
                print("JSON object starts with: \(jsonString.prefix(50))")

                // Debug: check if this extracted JSON contains our required fields
                print("Extracted JSON contains criteria: \(jsonString.contains("\"criteria\""))")
                print("Extracted JSON contains scores: \(jsonString.contains("\"scores\""))")

                return jsonString.data(using: .utf8)
            }
        } catch {
            print("Error in regex processing: \(error.localizedDescription)")
        }

        // If we reach here, try the entire string as a last resort
        print("Using entire string as fallback")
        return string.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8)
    }
}
