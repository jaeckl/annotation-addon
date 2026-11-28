@Lazy
@Component
class_name RunListKeeper
extends RefCounted

## Lazy so default_init "eager" does not try to build this invalid app product.
@Inject var purses: Array[RunPurse]
