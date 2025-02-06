type
    PicoTLSContext = ref object

proc initializePicoTLSContext(certificate: seq[byte], key: seq[byte]): PicoTLSContext =
    #ptls_openssl_sign_certificate_t sign_cert;

    
    #// Load the private key
    #FILE *fp = fopen("server.key", "rb");
    #if (!fp) {
    #    perror("Failed to open private key file");
    #    return -1;
    #}

    #EVP_PKEY *pkey = PEM_read_PrivateKey(fp, NULL, NULL, NULL);
    #fclose(fp);
    #if (!pkey) {
    #    perror("Failed to read private key");
    #    return -1;
    #}

    #// Initialize the certificate signing structure
    #ptls_openssl_init_sign_certificate(&sign_cert, pkey);
    #EVP_PKEY_free(pkey); // Free the key, as it's now managed by sign_cert

    #ptls_context_t ctx = {
    #    .random_bytes = ptls_openssl_random_bytes,
    #    .get_time = &ptls_get_time,
    #    .key_exchanges = ptls_openssl_key_exchanges,
    #    .cipher_suites = ptls_openssl_cipher_suites,
    #    .sign_certificate = &sign_cert.super,
    #};

    # TODO: implement custom certificate validation

proc loadCertificate(certificate: seq[byte]) =
  # ptls_load_certificates(&ctx, "server.crt"); # TODO: is it possible to pass the content instead?
  discard
        