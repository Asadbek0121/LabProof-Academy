class ExternalApiConfig {
  const ExternalApiConfig._();

  static const vecteezyApiKey = String.fromEnvironment(
    'VECTEEZY_API_KEY',
    defaultValue: '2wKomLAZm55gwkjDAt8QJeu1',
  );

  static const twentyFirstDevApiKey = String.fromEnvironment(
    'TWENTY_FIRST_DEV_API_KEY',
    defaultValue: '4ed873009f9ae66c41453c01760b43316bb39e4497c0d5ccc8700e08f5555cda',
  );
}
