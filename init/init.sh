#!/bin/sh
# Initialisation automatique de Wiki.js : compte admin + pages de départ
WIKI=http://wiki:3000
export PGHOST=db PGUSER="$POSTGRES_USER" PGPASSWORD="$POSTGRES_PASSWORD" PGDATABASE="$POSTGRES_DB"

echo "Attente de Wiki.js..."
until wget -q -O /dev/null "$WIKI"; do sleep 3; done

# Si l'admin existe déjà, l'initialisation a déjà été faite : on s'arrête
EXISTE=$(psql -tAc "SELECT count(*) FROM users WHERE email='$ADMIN_EMAIL'" 2>/dev/null || echo 0)
if [ -n "$EXISTE" ] && [ "$EXISTE" != "0" ]; then
  echo "Déjà initialisé, rien à faire."
  exit 0
fi

echo "Création du compte administrateur..."
wget -q -O - --header="Content-Type: application/json" \
  --post-data="{\"adminEmail\":\"$ADMIN_EMAIL\",\"adminPassword\":\"$ADMIN_PASSWORD\",\"adminPasswordConfirm\":\"$ADMIN_PASSWORD\",\"siteUrl\":\"http://localhost:8080\",\"telemetry\":false}" \
  "$WIKI/finalize"
echo

echo "Attente du redémarrage de Wiki.js..."
sleep 10
until wget -q -O /dev/null --header="Content-Type: application/json" \
  --post-data='{"query":"{ __typename }"}' "$WIKI/graphql"; do sleep 3; done

echo "Connexion en administrateur..."
REP=$(wget -q -O - --header="Content-Type: application/json" \
  --post-data="{\"query\":\"mutation { authentication { login(username: \\\"$ADMIN_EMAIL\\\", password: \\\"$ADMIN_PASSWORD\\\", strategy: \\\"local\\\") { jwt } } }\"}" \
  "$WIKI/graphql")
JWT=$(echo "$REP" | sed -n 's/.*"jwt":"\([^"]*\)".*/\1/p')

creer_page() {
  wget -q -O - --header="Content-Type: application/json" --header="Authorization: Bearer $JWT" \
    --post-data="{\"query\":\"mutation { pages { create(path: \\\"$1\\\", title: \\\"$2\\\", content: \\\"$3\\\", description: \\\"\\\", editor: \\\"markdown\\\", isPublished: true, isPrivate: false, locale: \\\"en\\\", tags: []) { responseResult { succeeded message } } } }\"}" \
    "$WIKI/graphql"
  echo
}

echo "Création du jeu de données..."
creer_page "home" "Accueil" '# Bienvenue\\n\\nCe wiki a été initialisé automatiquement par Docker Compose.'
creer_page "guide" "Guide" '# Guide\\n\\nPour modifier une page, cliquez sur le crayon en haut à droite.'
creer_page "faq" "FAQ" '# FAQ\\n\\nLes données sont stockées dans PostgreSQL et conservées grâce au volume db_data.'

echo "Initialisation terminée."
