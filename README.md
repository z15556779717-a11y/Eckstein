# Eckstein - Comprehensive Fitness Tracking App

Eckstein is a modern iOS fitness tracking app built with SwiftUI and Core Data, designed to help users track their workouts, diet, weight progress, and receive AI-powered coaching.

## Features

### 🏋️ Workout Tracking
- Comprehensive exercise library with categorization
- Set tracking with weight, reps, and rest time
- Workout history and progress visualization
- Support for custom exercises

### 🍎 Diet Management
- Meal tracking with nutritional information
- Calorie bank system for flexible dieting
- Food database with search functionality
- Daily/weekly nutrition summaries

### ⚖️ Weight Tracking
- Weight entry with progress charts
- BMI calculation and tracking
- Goal setting and progress monitoring
- Visual trend analysis

### 🤖 AI Coach
- Personalized workout and nutrition advice
- Form tips and exercise recommendations
- Progress analysis and suggestions
- Chat-based interaction with context awareness

### 📱 Additional Features
- Offline-first architecture with cloud sync
- Multi-language support (English, Hebrew)
- Dark mode support
- HealthKit integration
- Xiaomi scale support (coming soon)

## Technical Stack

- **Frontend**: SwiftUI, Core Data
- **Backend**: Supabase (PostgreSQL)
- **AI**: OpenAI GPT-4
- **Architecture**: MVVM with Coordinator pattern
- **Minimum iOS**: 17.0

## Setup Instructions

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0+ device or simulator
- Supabase account (for backend)
- OpenAI API key (for AI features)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/eckstein.git
cd eckstein
```

2. Open the project in Xcode:
```bash
open Eckstein/Eckstein.xcodeproj
```

3. Configure environment:
   - Copy `.env.example` to `.env`
   - Add your Supabase URL and keys
   - Add your OpenAI API key

4. Build and run the project in Xcode

### Database Setup

The app uses Supabase as the backend. The complete database schema is provided in `FINAL_VERSION_APP_DB.sql`. To set up:

1. Create a new Supabase project
2. Run the SQL script in the Supabase SQL editor
3. Update your `.env` file with the project credentials

## Architecture

The app follows a clean architecture pattern:

- **Core/**: Core services, utilities, and data models
- **Features/**: Feature modules (Workout, Diet, Weight, AI)
- **Resources/**: Assets, localizations, and configurations
- **App/**: App entry point and coordinators

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Built with SwiftUI and Core Data
- Powered by Supabase and OpenAI
- Designed for fitness enthusiasts by fitness enthusiasts