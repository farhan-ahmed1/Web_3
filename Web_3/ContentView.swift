//
//  ContentView.swift
//  Web_3
//
//  Created by Liban Ahmed on 6/17/23.
//  Continued by Farhan Ahmed on 2/6/24.
//
import SwiftUI
import Foundation
import SwiftSoup
import AVFoundation
import MessageUI
import Social
import MediaPlayer

// Import necessary libraries and frameworks. Some of the dependencies include SwiftUI, SwiftSoup, AVFoundation, MessageUI, Social, and MediaPlayer.
struct ContentView: View {
    // Define the main content view of the application.
    
    @State private var pages: [Page] = [] // Store web page data in an array.
    @State private var selectedTab = 1 // Track the selected tab.
    private let speechSynthesizer = AVSpeechSynthesizer() // Initialize a speech synthesizer.
    let player = AVPlayer() // Initialize an AVPlayer for media playback.
    @State private var appLogo: UIImage? // Store the app logo image.
    @State private var searchURL = "" // Store the user's input for web page URL.
    @State private var newPagesCount = 0 // Count of newly added web pages.
    @State private var recentSearches: [(url: String, title: String)] = [] // Store recent search history.
    @State private var settings = Settings() // Store user settings.
    @State private var folders: [Folder] = [] // Store folders for organizing pages.
    @Environment(\.colorScheme) var colorScheme // Get the color scheme (light/dark) from the environment.
    
    init() {
        // Initialize the ContentView.
        
        // Load the stored pages from a file when the app starts.
        let fileURL = getFileURL()
        if let data = try? Data(contentsOf: fileURL) {
            pages = try! PropertyListDecoder().decode([Page].self, from: data)
        }
    }
    
    var body: some View {
        // Define the body of the ContentView.
        
        TabView(selection: $selectedTab) {
            // Create a tab view with multiple tabs.
            
            // Tab 1: Recent Searches
            List(recentSearches, id: \.url) { search in
                Button(action: {
                    searchURL = search.url
                    extractTitleAndParagraphs(from: search.url)
                    selectedTab = 1
                }) {
                    Text(search.title)
                        .font(.subheadline)
                        .bold()
                        .padding()
                }
            }
            .tabItem {
                Label("Recent", systemImage: "clock.fill")
            }
            .tag(0)
            
            // Tab 2: Content
            NavigationView {
                List {
                    ForEach(pages, id: \.title) { page in
                        NavigationLink(destination: PageView(page: page)) {
                            Text(page.title)
                                .font(.subheadline)
                                .bold()
                                .padding()
                        }
                    }
                    .onDelete(perform: deletePage)
                }
                .navigationTitle("Content")
            }
            .tabItem {
                Label {
                    Text("Content")
                    if newPagesCount > 0 {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                            Text("\(newPagesCount)")
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                        .frame(width: 15, height: 15)
                    }
                } icon:
                {
                    Image(systemName: "doc.text.fill")
                }
            }
            .tag(1)
            
            // Tab 3: Search
            VStack {
                TextField("Enter URL", text: $searchURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                Button(action: {
                    extractTitleAndParagraphs(from: searchURL)
                }) {
                    Text("Search")
                        .font(.title)
                        .bold()
                        .padding()
                }
                Spacer()
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            .tag(2)
            
            // Tab 4: Settings
            NavigationView {
                SettingsView(settings: $settings)
            }
            .tabItem {
                Label("More", systemImage: "ellipsis.circle.fill")
            }
            .tag(3)
        }
        .preferredColorScheme(settings.darkMode ? .dark : .light) // Apply the user's preferred color scheme.
    }
    
    func playMedia() {
        // Function to play media from a URL.
        
        // Set up the player with the URL entered by the user
        if let url = URL(string: searchURL) {
            let playerItem = AVPlayerItem(url:url)
            player.replaceCurrentItem(with : playerItem )
        }
        
        // Start playback
        player.play()
    }
    
    func pauseMedia() {
        // Function to pause media playback.
        player.pause()
    }
    
    func extractTitleAndParagraphs(from url: String) {
        // Function to extract web page title and paragraphs from a given URL.
        
        guard let myURL = URL(string: url) else {
            print("Error: \(url) doesn't seem to be a valid URL")
            return
        }
        let task = URLSession.shared.dataTask(with: myURL) { data, response, error in
            guard let data = data, error == nil else {
                print("Error loading data from URL:", error ?? "")
                return
            }
            do {
                let html = String(data: data, encoding: .utf8)!
                let doc: Document = try SwiftSoup.parse(html)
                let title = try doc.title()
                var paragraphs: [String] = []
                for element in try doc.select("p") {
                    let paragraph = try element.text()
                    paragraphs.append(paragraph)
                }
                DispatchQueue.main.async {
                    let page = Page(title: title, paragraphs: paragraphs)
                    if !pages.contains(where: { $0.title == title }) {
                        pages.append(page)
                        newPagesCount += 1
                        recentSearches.insert((url: url, title: title), at: 0)
                        
                        // Save the pages array to file
                        let fileURL = getFileURL()
                        try? PropertyListEncoder().encode(pages).write(to: fileURL)
                    }
                    selectedTab = 1
                }
                let nextLink = try doc.select("div.nav-next > a.next_page").attr("href")
                if !nextLink.isEmpty {
                    extractTitleAndParagraphs(from: nextLink)
                }
            } catch let error {
                print("Error parsing HTML:", error)
            }
        }
        task.resume()
    }
    
    func speak(_ text: String) {
        // Function to speak text using the speech synthesizer.
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
        } catch {
            print("Failed to set AVAudioSession category:", error)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = settings.speechRate
        speechSynthesizer.speak(utterance)
    }
    
    func deletePage(at offsets: IndexSet) {
        // Function to delete a page at specified offsets.
        
        for index in offsets {
            let page = pages[index]
            if let searchIndex = recentSearches.firstIndex(where: { $0.title == page.title }) {
                recentSearches.remove(at: searchIndex)
            }
        }
        pages.remove(atOffsets: offsets)
        
        // Update the stored pages in a file
        let fileURL = getFileURL()
        try? PropertyListEncoder().encode(pages).write(to: fileURL)
    }
    
    func sharePage(_ page: Page) {
        // Function to share a page as text.
        
        let text = page.title + "\n\n" + page.paragraphs.joined(separator: "\n\n")
        let activityViewController = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            scene.windows.first?.rootViewController?.present(activityViewController, animated: true, completion: nil)
        }
    }
    
    func getFileURL() -> URL {
        // Function to get the file URL for storing pages.
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent("pages.plist")
        return fileURL
    }
    
    struct SettingsView: View {
        @Binding var settings: Settings // Represents the user settings.
        
        var body: some View {
            Form {
                Toggle("Dark Mode", isOn: $settings.darkMode) // Toggle switch for dark mode.
                HStack {
                    Text("Speech Rate") // Label for speech rate setting.
                    Slider(value: $settings.speechRate, in: 0...1) // Slider for adjusting speech rate.
                }
            }
            .navigationTitle("Settings") // Set the navigation title for this view.
        }
    }
    
    struct Folder: Identifiable, Equatable, Hashable {
        static func == (lhs: Folder, rhs: Folder) -> Bool {
            return lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        let id = UUID() // Unique identifier for the folder.
        var name: String // Name of the folder.
        var pages: [Page] // Pages contained within the folder.
    }
    
    struct Settings {
        var darkMode: Bool = true // Indicates whether dark mode is enabled.
        var speechRate: Float = 0.67 // Speech rate setting.
    }
    
    struct PageView: View {
        let page: Page // Represents a page to be displayed.
        
        var body: some View {
            ScrollView {
                VStack(alignment: .leading) {
                    
                    Text(page.title)
                        .font(.title)
                        .bold()
                    ForEach(page.paragraphs, id: \.self) { paragraph in
                        
                        Text(paragraph)
                            .padding(.top)
                    }
                }.padding()
            }
        }
    }
    
    struct Page: Codable {
        let title: String // Title of the page.
        let paragraphs: [String] // Paragraphs of text within the page.
    }
}







