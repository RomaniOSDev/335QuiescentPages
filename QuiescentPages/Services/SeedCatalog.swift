import Foundation

enum SeedCatalog {
    struct SeedQuote {
        let text: String
        let translatedText: String
        let language: String
        let bookTitle: String
        let author: String
        let page: String
        let notes: String
    }

    static let books: [(title: String, author: String, notes: String, tone: Int)] = [
        (
            "Pride and Prejudice",
            "Jane Austen",
            "Public-domain classic. Use these lines to warm up the desk before adding your own page captures.",
            0
        ),
        (
            "The Picture of Dorian Gray",
            "Oscar Wilde",
            "Aesthetic and moral tension — good material for flashcard contrast.",
            1
        ),
        (
            "Alice's Adventures in Wonderland",
            "Lewis Carroll",
            "Playful English with clear rhythm; strong for Spanish and French practice.",
            2
        )
    ]

    static let quotes: [SeedQuote] = [
        SeedQuote(
            text: "It is a truth universally acknowledged, that a single man in possession of a good fortune, must be in want of a wife.",
            translatedText: "Es una verdad universalmente reconocida que un soltero poseedor de una gran fortuna debe querer casarse.",
            language: "es",
            bookTitle: "Pride and Prejudice",
            author: "Jane Austen",
            page: "1",
            notes: "Opening line — practice formal tone."
        ),
        SeedQuote(
            text: "I declare after all there is no enjoyment like reading!",
            translatedText: "¡Declaro que, después de todo, no hay gozo comparable a la lectura!",
            language: "es",
            bookTitle: "Pride and Prejudice",
            author: "Jane Austen",
            page: "37",
            notes: "Miss Bingley — irony included."
        ),
        SeedQuote(
            text: "The only way to get rid of a temptation is to yield to it.",
            translatedText: "La única manera de librarse de una tentación es ceder a ella.",
            language: "es",
            bookTitle: "The Picture of Dorian Gray",
            author: "Oscar Wilde",
            page: "21",
            notes: "Lord Henry — short and sharp for cards."
        ),
        SeedQuote(
            text: "Nowadays people know the price of everything and the value of nothing.",
            translatedText: "De nos jours, les gens connaissent le prix de tout et la valeur de rien.",
            language: "fr",
            bookTitle: "The Picture of Dorian Gray",
            author: "Oscar Wilde",
            page: "44",
            notes: "French practice set."
        ),
        SeedQuote(
            text: "Curiouser and curiouser!",
            translatedText: "Immer merkwürdiger und merkwürdiger!",
            language: "de",
            bookTitle: "Alice's Adventures in Wonderland",
            author: "Lewis Carroll",
            page: "12",
            notes: "Tiny card — great for first German review."
        ),
        SeedQuote(
            text: "Who in the world am I? Ah, that's the great puzzle.",
            translatedText: "Chi sono io al mondo? Ah, questo è il grande enigma.",
            language: "it",
            bookTitle: "Alice's Adventures in Wonderland",
            author: "Lewis Carroll",
            page: "18",
            notes: "Identity motif — pair with your own scans."
        ),
        SeedQuote(
            text: "There is nothing like staying at home for real comfort.",
            translatedText: "Il n'y a rien de tel que de rester chez soi pour un vrai confort.",
            language: "fr",
            bookTitle: "Pride and Prejudice",
            author: "Jane Austen",
            page: "52",
            notes: "Domestic register for French learners."
        ),
        SeedQuote(
            text: "Experience is merely the name men gave to their mistakes.",
            translatedText: "Erfahrung ist nur der Name, den die Menschen ihren Fehlern gaben.",
            language: "de",
            bookTitle: "The Picture of Dorian Gray",
            author: "Oscar Wilde",
            page: "58",
            notes: "Aphorism — good spaced-repetition candidate."
        )
    ]
}
