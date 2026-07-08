/**
 * Site-wide configuration.
 * Centralizes site metadata, navigation, and social links so they can be
 * updated in one place.
 */

export const SITE = {
  name: 'mdupapers',
  brandName: 'MDU PYQ & Notes',
  shortName: 'mdupapers',
  title: 'MDU PYQ & Notes — Free Previous Year Paper PDF Download',
  description:
    'Download free MDU Rohtak previous year question papers PDF & notes. Instant access for all courses & semesters. Direct PDF download with no ads or sign-up!',
  url: 'https://mdupapers.com',
  ogImage: '/og-image.svg',
  author: 'MDU Papers Team',
  email: 'contact@mdupapers.com',
  locale: 'en_IN',
  university: 'Maharshi Dayanand University',
  universityUrl: 'https://mdu.ac.in',
} as const;

export const NAV_LINKS = [
  { label: 'Home', href: '/' },
  { label: 'Courses', href: '/courses/' },
  { label: 'Blog', href: '/blog/' },
  { label: 'Contribute', href: '/contribute/' },
  { label: 'About', href: '/about/' },
] as const;

export const FOOTER_LINKS = {
  quickLinks: [
    { label: 'Home', href: '/' },
    { label: 'All Courses', href: '/courses/' },
    { label: 'Contribute Papers', href: '/contribute/' },
    { label: 'Search', href: '/search/' },
    { label: 'Blog', href: '/blog/' },
  ],
  popularCourses: [
    { label: 'BCA Papers', href: '/bca/' },
    { label: 'B.Tech CSE Papers', href: '/btech-cse/' },
    { label: 'BCom Papers', href: '/bcom/' },
    { label: 'MBA Papers', href: '/mba/' },
  ],
  legal: [
    { label: 'About Us', href: '/about/' },
    { label: 'Contact', href: '/contact/' },
    { label: 'Privacy Policy', href: '/privacy/' },
    { label: 'Terms of Service', href: '/terms/' },
    { label: 'Disclaimer', href: '/disclaimer/' },
  ],
} as const;

export const SOCIAL_LINKS = [
  { label: 'Telegram', href: 'https://t.me/mdupapers', icon: 'send' },
  { label: 'WhatsApp', href: 'https://whatsapp.com/channel/mdupapers', icon: 'message-circle' },
  { label: 'Instagram', href: 'https://instagram.com/mdupapers', icon: 'instagram' },
] as const;

export const GA_ID = import.meta.env.PUBLIC_GA_ID || '';

/** Ordinal labels used for semester slugs e.g. 1 -> "1st-sem" */
export const SEMESTER_SLUGS: Record<number, string> = {
  1: '1st-sem',
  2: '2nd-sem',
  3: '3rd-sem',
  4: '4th-sem',
  5: '5th-sem',
  6: '6th-sem',
  7: '7th-sem',
  8: '8th-sem',
  9: '9th-sem',
  10: '10th-sem',
};
