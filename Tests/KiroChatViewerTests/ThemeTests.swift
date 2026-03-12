import Foundation
import Testing
@testable import KiroChatViewer

// MARK: - ThemeMode Tests

@Suite struct ThemeModeTests {

    @Test func allCasesExist() {
        let cases = ThemeMode.allCases
        #expect(cases.count == 4)
        #expect(cases.contains(.system))
        #expect(cases.contains(.light))
        #expect(cases.contains(.dark))
        #expect(cases.contains(.kiro))
    }

    @Test func rawValueRoundTrip() {
        for mode in ThemeMode.allCases {
            #expect(ThemeMode(rawValue: mode.rawValue) == mode)
        }
    }

    @Test func invalidRawValueReturnsNil() {
        #expect(ThemeMode(rawValue: "Neon") == nil)
        #expect(ThemeMode(rawValue: "") == nil)
    }

    @Test func idMatchesRawValue() {
        for mode in ThemeMode.allCases {
            #expect(mode.id == mode.rawValue)
        }
    }

    @Test func iconIsNonEmpty() {
        for mode in ThemeMode.allCases {
            #expect(!mode.icon.isEmpty)
        }
    }

    @Test func colorSchemeMapping() {
        #expect(ThemeMode.system.colorScheme == nil)
        #expect(ThemeMode.light.colorScheme != nil)
        #expect(ThemeMode.dark.colorScheme != nil)
        #expect(ThemeMode.kiro.colorScheme != nil)
    }
}

// MARK: - AppTheme Tests

@Suite struct AppThemeTests {

    @Test func builtInThemesHaveDistinctIds() {
        let ids = [AppTheme.light.id, AppTheme.dark.id, AppTheme.kiro.id]
        #expect(Set(ids).count == 3)
    }

    @Test func builtInThemesAreBuiltIn() {
        #expect(AppTheme.light.isBuiltIn == true)
        #expect(AppTheme.dark.isBuiltIn == true)
        #expect(AppTheme.kiro.isBuiltIn == true)
    }

    @Test func codableRoundTrip() throws {
        let theme = AppTheme(
            id: "custom-1", name: "Ocean", accentHex: "#0077FF",
            sidebarHex: "#001122", backgroundHex: "#000033",
            userBubbleHex: "#003366", assistantBubbleHex: "#002244",
            isBuiltIn: false, iconName: "drop"
        )
        let data = try JSONEncoder().encode(theme)
        let decoded = try JSONDecoder().decode(AppTheme.self, from: data)
        #expect(decoded.id == "custom-1")
        #expect(decoded.name == "Ocean")
        #expect(decoded.accentHex == "#0077FF")
        #expect(decoded.isBuiltIn == false)
        #expect(decoded.iconName == "drop")
    }

    @Test func hexValuesAreValidFormat() {
        let themes = [AppTheme.light, AppTheme.dark, AppTheme.kiro]
        for theme in themes {
            for hex in [theme.accentHex, theme.sidebarHex, theme.backgroundHex, theme.userBubbleHex, theme.assistantBubbleHex] {
                #expect(hex.hasPrefix("#"))
                #expect(hex.count == 7) // #RRGGBB
            }
        }
    }

    @Test func availableIconsIsNonEmpty() {
        #expect(!AppTheme.availableIcons.isEmpty)
    }

    @Test func themeEquality() {
        let a = AppTheme(id: "t1", name: "A", accentHex: "#000", sidebarHex: "#000", backgroundHex: "#000", userBubbleHex: "#000", assistantBubbleHex: "#000", isBuiltIn: false)
        let b = AppTheme(id: "t1", name: "A", accentHex: "#000", sidebarHex: "#000", backgroundHex: "#000", userBubbleHex: "#000", assistantBubbleHex: "#000", isBuiltIn: false)
        #expect(a == b)
    }

    @Test func themeArrayCodableRoundTrip() throws {
        let themes = [AppTheme.light, AppTheme.dark]
        let data = try JSONEncoder().encode(themes)
        let decoded = try JSONDecoder().decode([AppTheme].self, from: data)
        #expect(decoded.count == 2)
        #expect(decoded[0].id == "light")
    }
}
