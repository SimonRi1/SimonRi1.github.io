# Usa un'immagine Ruby ufficiale che supporta nativamente i Raspberry (ARM64)
FROM ruby:3.2-bullseye

# Installa gli strumenti di sistema per compilare le gemme
RUN apt-get update && apt-get install -y build-essential nodejs

# Imposta la cartella di lavoro interna
WORKDIR /srv/jekyll

# Installa Jekyll globalmente nel contenitore
RUN gem install jekyll bundler

# All'avvio: installa le dipendenze dal tuo Gemfile e poi avvia il server live
CMD bundle install && bundle exec jekyll serve --watch --force_polling --host 0.0.0.0
