dic = {
    # Single Hero: own app id and name, so it installs next to the official VCMI apps
    "applicationIdSuffix": ".singlehero",
    "applicationLabel": "Single Hero",
    "applicationVariant": "daily",
    "signingConfig": "dailySigning",
}
print(";".join([f"{key}={value}" for key, value in dic.items()]))
