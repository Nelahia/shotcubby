/// French for the texts the Rust side shows (tray menu, shortcut names, dialogs
/// and the errors Settings prints). Keyed by the English text, see `i18n::tr`.
pub const FRENCH: &[(&str, &str)] = &[
    // Tray menu
    ("Search…", "Rechercher…"),
    ("Open Folder", "Ouvrir le dossier"),
    ("Settings…", "Paramètres…"),
    ("Check for Updates…", "Rechercher des mises à jour…"),
    ("Quit ShotCubby", "Quitter ShotCubby"),
    // Shortcut names
    ("Open Spotlight search", "Ouvrir la recherche"),
    ("Capture full screen", "Capturer tout l’écran"),
    ("Capture a region", "Capturer une zone"),
    // Dialogs
    ("Choose the folder ShotCubby should watch", "Choisir le dossier que ShotCubby doit surveiller"),
    ("Choose where ShotCubby keeps your screenshots", "Choisir où ShotCubby conserve vos captures"),
    // Shortcuts
    (
        "Shortcut needs a modifier key (or be a function / PrintScreen key)",
        "Le raccourci doit contenir une touche de modification (ou être une touche de fonction / Impr. écran)",
    ),
    ("Shortcut unavailable (already in use?)", "Raccourci indisponible (déjà utilisé ?)"),
    ("Default shortcut unavailable (already in use?)", "Raccourci par défaut indisponible (déjà utilisé ?)"),
    // Screenshots
    ("Could not move the file to the Recycle Bin", "Impossible de déplacer le fichier dans la Corbeille"),
    ("Screenshot not found", "Capture introuvable"),
    ("Could not rename", "Impossible de renommer"),
    (
        "That name is empty or only has characters Windows does not allow",
        "Ce nom est vide ou ne contient que des caractères interdits par Windows",
    ),
    ("The file has no folder", "Le fichier n’a pas de dossier"),
    // Moving the screenshots folder
    ("That is already the current folder.", "C’est déjà le dossier actuel."),
    ("Choose a folder outside the current one.", "Choisissez un dossier en dehors du dossier actuel."),
    ("That folder isn't empty.", "Ce dossier n’est pas vide."),
    ("ShotCubby can't write there.", "ShotCubby ne peut pas écrire à cet endroit."),
    (
        "Couldn't copy the screenshots there. Nothing was moved.",
        "Impossible de copier les captures à cet endroit. Rien n’a été déplacé.",
    ),
    // AI naming
    ("Unknown provider", "Fournisseur inconnu"),
    ("Could not build the test picture", "Impossible de créer l’image de test"),
    ("The test was interrupted", "Le test a été interrompu"),
    ("The credential store is unavailable", "Le gestionnaire d’identifiants est indisponible"),
    ("The key is empty", "La clé est vide"),
    ("Could not save the key", "Impossible d’enregistrer la clé"),
    ("No API key saved", "Aucune clé API enregistrée"),
    ("Could not read the screenshot", "Impossible de lire la capture"),
    ("The provider returned no title", "Le fournisseur n’a renvoyé aucun titre"),
    ("Renamed to", "Renommée en"),
    ("Could not reach", "Impossible de joindre"),
    ("This API key is not scoped to a workspace", "Cette clé API n’est liée à aucun espace de travail"),
    ("The account has no credit left", "Le compte n’a plus de crédit"),
    ("The API key was rejected", "La clé API a été refusée"),
    ("Too many requests, try again in a moment", "Trop de requêtes, réessayez dans un instant"),
    ("The provider answered with HTTP", "Le fournisseur a répondu HTTP"),
    ("No title in Anthropic's answer", "Aucun titre dans la réponse d’Anthropic"),
    ("No title in OpenAI's answer", "Aucun titre dans la réponse d’OpenAI"),
    ("stop reason", "motif d’arrêt"),
    ("finish reason", "motif de fin"),
    ("Unreadable answer from Anthropic", "Réponse illisible d’Anthropic"),
    ("Unreadable answer from OpenAI", "Réponse illisible d’OpenAI"),
];
