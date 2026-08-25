#!/usr/bin/env bash
set -e

# Install Flutter
git clone https://github.com/flutter/flutter.git --depth 1 -b stable
export PATH="$PWD/flutter/bin:$PATH"

flutter --version

# Generate .env from Vercel environment variables
cat > .env <<EOL
SUPABASE_URL=$SUPABASE_URL
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
FEATURE_HALAQA=$FEATURE_HALAQA
FEATURE_MINBAR=$FEATURE_MINBAR
FEATURE_SCHOLAR_AI=$FEATURE_SCHOLAR_AI
FEATURE_SEED_SOCIAL=$FEATURE_SEED_SOCIAL
FEATURE_MULTILINGUAL=$FEATURE_MULTILINGUAL
UMMAH_API_KEY=$UMMAH_API_KEY
GROQ_API_KEY=$GROQ_API_KEY
EOL

chmod +x tools/build_web.sh
./tools/build_web.sh