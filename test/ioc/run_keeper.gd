@Lazy
@Component
class_name RunKeeper
extends RefCounted

## Lazy so default_init "eager" does not try to build this invalid app product.
@Inject var wallet: RunWallet
