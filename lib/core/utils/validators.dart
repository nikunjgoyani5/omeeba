import 'package:omeeba_new/core/theme/strings.dart';

class ValidationUtils {
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.emailRequired;
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) return AppStrings.enterValidEmail;
    return null;
  }

  static String? validatePhone(String? value, {String? countryCode}) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.mobileNumberRequired;
    }

    // Country-specific phone number length validation
    if (countryCode != null) {
      final phoneLength = getPhoneNumberLength(countryCode);
      if (phoneLength != null) {
        final digitsOnly = value.trim().replaceAll(RegExp(r'[^\d]'), '');
        if (digitsOnly.length != phoneLength) {
          return 'Enter a valid $phoneLength-digit phone number';
        }
        return null;
      }
    }

    // Default validation if country code not provided
    final phoneRegex = RegExp(r'^[6-9]\d{9}$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return AppStrings.enterValidPhoneNumber;
    }
    return null;
  }

  // Map of country codes to phone number lengths (without country code)
  static int? getPhoneNumberLength(String countryCode) {
    final phoneLengths = {
      'AF': 9, // Afghanistan
      'AL': 9, // Albania
      'DZ': 9, // Algeria
      'AD': 9, // Andorra
      'AO': 9, // Angola
      'AR': 10, // Argentina
      'AM': 8, // Armenia
      'AU': 9, // Australia
      'AT': 10, // Austria
      'AZ': 9, // Azerbaijan
      'BS': 7, // Bahamas
      'BH': 8, // Bahrain
      'BD': 10, // Bangladesh
      'BB': 7, // Barbados
      'BY': 9, // Belarus
      'BE': 9, // Belgium
      'BZ': 7, // Belize
      'BJ': 8, // Benin
      'BT': 8, // Bhutan
      'BO': 8, // Bolivia
      'BA': 8, // Bosnia & Herzegovina
      'BW': 8, // Botswana
      'BR': 11, // Brazil
      'BN': 7, // Brunei
      'BG': 9, // Bulgaria
      'BF': 8, // Burkina Faso
      'BI': 8, // Burundi
      'KH': 9, // Cambodia
      'CM': 9, // Cameroon
      'CA': 10, // Canada
      'CV': 7, // Cape Verde
      'CF': 8, // Central African Republic
      'TD': 8, // Chad
      'CL': 9, // Chile
      'CN': 11, // China
      'CO': 10, // Colombia
      'KM': 7, // Comoros
      'CG': 9, // Congo
      'CR': 8, // Costa Rica
      'HR': 9, // Croatia
      'CU': 8, // Cuba
      'CY': 8, // Cyprus
      'CZ': 9, // Czech Republic
      'DK': 8, // Denmark
      'DJ': 8, // Djibouti
      'DO': 10, // Dominican Republic
      'EC': 9, // Ecuador
      'EG': 10, // Egypt
      'SV': 8, // El Salvador
      'GQ': 9, // Equatorial Guinea
      'ER': 8, // Eritrea
      'EE': 9, // Estonia
      'ET': 9, // Ethiopia
      'FJ': 7, // Fiji
      'FI': 9, // Finland
      'FR': 9, // France
      'GA': 9, // Gabon
      'GM': 7, // Gambia
      'GE': 9, // Georgia
      'DE': 11, // Germany
      'GH': 10, // Ghana
      'GR': 10, // Greece
      'GD': 7, // Grenada
      'GT': 8, // Guatemala
      'GN': 8, // Guinea
      'GW': 8, // Guinea-Bissau
      'GY': 7, // Guyana
      'HT': 8, // Haiti
      'HN': 8, // Honduras
      'HK': 8, // Hong Kong
      'HU': 9, // Hungary
      'IS': 7, // Iceland
      'IN': 10, // India
      'ID': 9, // Indonesia
      'IR': 10, // Iran
      'IQ': 10, // Iraq
      'IE': 9, // Ireland
      'IL': 9, // Israel
      'IT': 10, // Italy
      'JM': 7, // Jamaica
      'JP': 10, // Japan
      'JO': 9, // Jordan
      'KZ': 10, // Kazakhstan
      'KE': 9, // Kenya
      'KI': 7, // Kiribati
      'KR': 10, // South Korea
      'KW': 8, // Kuwait
      'KG': 9, // Kyrgyzstan
      'LA': 8, // Laos
      'LV': 8, // Latvia
      'LB': 8, // Lebanon
      'LS': 8, // Lesotho
      'LR': 7, // Liberia
      'LY': 9, // Libya
      'LI': 7, // Liechtenstein
      'LT': 8, // Lithuania
      'LU': 8, // Luxembourg
      'MO': 8, // Macau
      'MK': 8, // North Macedonia
      'MG': 9, // Madagascar
      'MW': 9, // Malawi
      'MY': 9, // Malaysia
      'MV': 7, // Maldives
      'ML': 8, // Mali
      'MT': 8, // Malta
      'MH': 7, // Marshall Islands
      'MR': 9, // Mauritania
      'MU': 8, // Mauritius
      'MX': 10, // Mexico
      'FM': 7, // Micronesia
      'MD': 8, // Moldova
      'MC': 8, // Monaco
      'MN': 8, // Mongolia
      'ME': 8, // Montenegro
      'MA': 9, // Morocco
      'MZ': 9, // Mozambique
      'MM': 9, // Myanmar
      'NA': 9, // Namibia
      'NR': 7, // Nauru
      'NP': 10, // Nepal
      'NL': 9, // Netherlands
      'NZ': 9, // New Zealand
      'NI': 8, // Nicaragua
      'NE': 8, // Niger
      'NG': 10, // Nigeria
      'NO': 8, // Norway
      'OM': 8, // Oman
      'PK': 10, // Pakistan
      'PW': 7, // Palau
      'PA': 8, // Panama
      'PG': 8, // Papua New Guinea
      'PY': 8, // Paraguay
      'PE': 9, // Peru
      'PH': 10, // Philippines
      'PL': 9, // Poland
      'PT': 9, // Portugal
      'QA': 8, // Qatar
      'RO': 9, // Romania
      'RU': 10, // Russia
      'RW': 9, // Rwanda
      'KN': 7, // Saint Kitts & Nevis
      'LC': 7, // Saint Lucia
      'VC': 7, // Saint Vincent & Grenadines
      'WS': 7, // Samoa
      'SM': 8, // San Marino
      'ST': 9, // Sao Tome & Principe
      'SA': 9, // Saudi Arabia
      'SN': 9, // Senegal
      'RS': 9, // Serbia
      'SC': 7, // Seychelles
      'SL': 8, // Sierra Leone
      'SG': 8, // Singapore
      'SK': 9, // Slovakia
      'SI': 8, // Slovenia
      'SB': 7, // Solomon Islands
      'SO': 8, // Somalia
      'ZA': 9, // South Africa
      'ES': 9, // Spain
      'LK': 9, // Sri Lanka
      'SD': 9, // Sudan
      'SR': 7, // Suriname
      'SZ': 8, // Eswatini
      'SE': 9, // Sweden
      'CH': 9, // Switzerland
      'SY': 9, // Syria
      'TW': 9, // Taiwan
      'TJ': 9, // Tajikistan
      'TZ': 9, // Tanzania
      'TH': 9, // Thailand
      'TL': 8, // Timor-Leste
      'TG': 8, // Togo
      'TO': 7, // Tonga
      'TT': 7, // Trinidad & Tobago
      'TN': 8, // Tunisia
      'TR': 10, // Turkey
      'TM': 8, // Turkmenistan
      'TV': 7, // Tuvalu
      'UG': 9, // Uganda
      'UA': 9, // Ukraine
      'AE': 9, // UAE
      'GB': 10, // United Kingdom
      'US': 10, // United States
      'UY': 8, // Uruguay
      'UZ': 9, // Uzbekistan
      'VU': 7, // Vanuatu
      'VE': 10, // Venezuela
      'VN': 9, // Vietnam
      'YE': 9, // Yemen
      'ZM': 9, // Zambia
      'ZW': 9, // Zimbabwe
      'AS': 10, // American Samoa
      'AI': 10, // Anguilla
      'AG': 10, // Antigua & Barbuda
      'BM': 10, // Bermuda
      'VG': 10, // British Virgin Islands
      'KY': 10, // Cayman Islands
      'DM': 10, // Dominica
      'GU': 10, // Guam
      'MS': 10, // Montserrat
      'MP': 10, // Northern Mariana Islands
      'PR': 10, // Puerto Rico
      'SX': 10, // Sint Maarten
      'TC': 10, // Turks & Caicos Islands
      'VI': 10, // U.S. Virgin Islands
    };

    return phoneLengths[countryCode.toUpperCase()];
  }

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.nameRequired;
    if (value.trim().length < 2) return AppStrings.nameTooShort;
    return null;
  }

  static String? validateDescription(String? value) {
    if (value == null || value.trim().isEmpty) return 'Description required';
    if (value.trim().length < 2) return 'Description too short';
    return null;
  }

  static String? validateSubject(String? value) {
    if (value == null || value.trim().isEmpty) return 'Subject required';
    if (value.trim().length < 2) return 'subject too short';
    return null;
  }

  static String? validateAddress(String? value) {
    if (value == null || value.trim().isEmpty) return 'Address required';
    if (value.trim().length < 2) return 'Address too short';
    return null;
  }

  static String? validateWebsite(String? value) {
    if (value == null || value.trim().isEmpty) return 'Website required';
    if (value.trim().length < 2) return 'Website too short';
    return null;
  }

  static String? validateTotalRoom(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter total rooms';

    return null;
  }

  static String? validateTotalFloor(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter total floors';

    return null;
  }

  static String? validateYearBuilt(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter year built';

    return null;
  }

  static String? validateLastRenovated(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter last renovated year';

    return null;
  }

  static String? validateDistance(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter Distance';

    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return AppStrings.passwordRequired;
    if (value.length < 6) return AppStrings.passwordMinLength;
    return null;
  }
}
