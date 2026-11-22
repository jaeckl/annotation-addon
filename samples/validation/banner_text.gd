class_name BannerText
extends RefCounted

## Example target. The blank title fails NonBlank and Pattern. NotEmpty
## still matches, because the string is not empty.
@NotEmpty
@NonBlank
@Pattern(regexp="[A-Za-z]+")
var title: String = "   "
