/**
 * Generates supabase/seed-subjects.sql for ALL courses, semester-wise.
 *
 * Subjects are based on standard MDU / Indian university curricula. They are a
 * sensible starting point; edit/add/remove via the admin panel as needed.
 *
 * Run:  node scripts/genSubjects.mjs
 */
import { writeFileSync } from 'node:fs';

// Slugify mirrors src/lib/utils.ts
const slugify = (t) =>
  t.toString().toLowerCase().trim()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-');

// ---- Reusable subject sets ----------------------------------------------

// Generic language/ability-enhancement papers common to many UG courses (NEP).
const compEnglish = (n) => `English-${n}`;
const compHindi = (n) => `Hindi-${n}`;

// BA (general) — common humanities core across 6 semesters.
const ba = {
  1: ['English-I', 'Hindi-I', 'Environmental Studies', 'History of India-I', 'Political Science: Indian Constitution', 'Economics: Microeconomics-I'],
  2: ['English-II', 'Hindi-II', 'History of India-II', 'Political Science: Indian Government', 'Economics: Microeconomics-II', 'Sociology: Introduction'],
  3: ['English-III', 'History of India-III', 'Principles of Political Science-I', 'Macroeconomics-I', 'Public Administration', 'Geography of India'],
  4: ['English-IV', 'History of Modern India', 'Principles of Political Science-II', 'Macroeconomics-II', 'Indian Political Thinkers', 'Sociology of India'],
  5: ['Comparative Politics', 'Development Economics', 'Ancient & Medieval World History', 'Indian Economy', 'Public Policy', 'Social Research Methods'],
  6: ['International Relations', 'Modern World History', 'Indian Foreign Policy', 'Statistics for Economics', 'Human Rights', 'Project Work'],
};

const baSubjectStream = (subject, perSem) =>
  Object.fromEntries(Object.entries(perSem).map(([s, arr]) => [s, arr]));

// BCom core (6 sem)
const bcom = {
  1: ['Financial Accounting', 'Business Economics', 'Business Law', 'Business Organization & Management', 'Business Communication', 'Computer Fundamentals'],
  2: ['Corporate Accounting', 'Macro Economics', 'Company Law', 'Principles of Marketing', 'Business Statistics', 'Environmental Studies'],
  3: ['Cost Accounting', 'Income Tax Law & Practice', 'Banking & Insurance', 'Business Mathematics', 'Indian Economy', 'E-Commerce'],
  4: ['Management Accounting', 'Goods & Services Tax (GST)', 'Auditing', 'Financial Management', 'Human Resource Management', 'Entrepreneurship'],
  5: ['Advanced Accounting', 'Corporate Tax Planning', 'Financial Markets & Institutions', 'International Business', 'Principles of Investment', 'Business Environment'],
  6: ['Advanced Cost Accounting', 'Indirect Tax', 'Strategic Management', 'Project Work', 'Office Management', 'Goods & Services Tax-II'],
};

// BBA core (6 sem)
const bba = {
  1: ['Principles of Management', 'Business Economics', 'Financial Accounting', 'Business Communication', 'Business Mathematics', 'Computer Applications'],
  2: ['Organizational Behaviour', 'Managerial Economics', 'Cost Accounting', 'Business Statistics', 'Business Law', 'Environmental Management'],
  3: ['Marketing Management', 'Financial Management', 'Human Resource Management', 'Production & Operations Management', 'Business Research Methods', 'Management Information Systems'],
  4: ['Consumer Behaviour', 'Corporate Finance', 'Training & Development', 'Operations Research', 'Entrepreneurship Development', 'Business Environment'],
  5: ['Sales & Distribution Management', 'Investment Management', 'Compensation Management', 'Strategic Management', 'International Business', 'Project Management'],
  6: ['Advertising & Brand Management', 'Financial Markets', 'Performance Management', 'Business Ethics & Corporate Governance', 'Project Work', 'E-Business'],
};

// BCA core (6 sem)
const bca = {
  1: ['Fundamentals of Computers', 'Programming in C', 'Mathematics-I', 'Communication Skills', 'Digital Electronics', 'PC Software'],
  2: ['Data Structures Using C', 'Object Oriented Programming (C++)', 'Mathematics-II', 'Computer Organization', 'Operating Systems', 'Environmental Studies'],
  3: ['Database Management System', 'Computer Networks', 'Java Programming', 'Mathematics-III', 'System Analysis & Design', 'Web Technologies'],
  4: ['Software Engineering', 'Python Programming', 'Computer Graphics', 'Data Communication', 'Microprocessors', 'Numerical Methods'],
  5: ['Design & Analysis of Algorithms', 'E-Commerce', '.NET Programming', 'Artificial Intelligence', 'Information Security', 'Operating Systems-II'],
  6: ['Cloud Computing', 'Mobile Application Development', 'Data Science Fundamentals', 'Project Work', 'Software Testing', 'Internet of Things'],
};

// BSc CS (6 sem)
const bscCs = {
  1: ['Programming Fundamentals (C)', 'Mathematics-I', 'Digital Logic', 'Physics-I', 'Communication Skills', 'Environmental Studies'],
  2: ['Data Structures', 'Mathematics-II', 'Object Oriented Programming', 'Computer Organization', 'Discrete Mathematics', 'Statistics'],
  3: ['Database Management System', 'Operating Systems', 'Java Programming', 'Computer Networks', 'Theory of Computation', 'Numerical Methods'],
  4: ['Design & Analysis of Algorithms', 'Software Engineering', 'Web Technologies', 'Microprocessors', 'Python Programming', 'Probability & Statistics'],
  5: ['Artificial Intelligence', 'Computer Graphics', 'Compiler Design', 'Information Security', 'Data Mining', 'Elective-I'],
  6: ['Machine Learning', 'Cloud Computing', 'Mobile Computing', 'Project Work', 'Big Data Analytics', 'Elective-II'],
};

// Generic BSc science (Physics/Chemistry/Maths/Biotech/Botany/Zoology) — uses subject name.
const bscScience = (core) => ({
  1: [`${core}-I`, 'Mathematics-I', 'English Communication', 'Environmental Studies', `${core} Lab-I`],
  2: [`${core}-II`, 'Mathematics-II', 'Technical Writing', `${core} Lab-II`, 'Elective-I'],
  3: [`${core}-III`, 'Applied Mathematics', `${core} Practical-III`, 'Research Methodology', 'Elective-II'],
  4: [`${core}-IV`, 'Statistics', `${core} Practical-IV`, 'Computational Methods', 'Elective-III'],
  5: [`Advanced ${core}-I`, `${core} Special Paper-I`, `${core} Lab-V`, 'Instrumentation', 'Elective-IV'],
  6: [`Advanced ${core}-II`, `${core} Special Paper-II`, 'Project Work', `${core} Lab-VI`, 'Elective-V'],
});

// B.Tech common first year + branch specific (8 sem)
const btechCommon = {
  1: ['Engineering Mathematics-I', 'Engineering Physics', 'Programming for Problem Solving', 'Basic Electrical Engineering', 'English Communication'],
  2: ['Engineering Mathematics-II', 'Engineering Chemistry', 'Engineering Graphics & Design', 'Basic Electronics', 'Environmental Sciences'],
};
const btech = (branch) => {
  const map = {
    'btech-cse': {
      3: ['Data Structures & Algorithms', 'Discrete Mathematics', 'Digital Logic Design', 'Object Oriented Programming', 'Computer Organization'],
      4: ['Design & Analysis of Algorithms', 'Database Management Systems', 'Operating Systems', 'Microprocessors & Interfacing', 'Theory of Computation'],
      5: ['Computer Networks', 'Software Engineering', 'Formal Languages & Automata', 'Web Technologies', 'Probability & Statistics'],
      6: ['Compiler Design', 'Artificial Intelligence', 'Computer Graphics', 'Data Mining', 'Elective-I'],
      7: ['Machine Learning', 'Cloud Computing', 'Information Security', 'Project-I', 'Elective-II'],
      8: ['Big Data Analytics', 'Internet of Things', 'Project-II', 'Elective-III', 'Industrial Training'],
    },
    'btech-it': {
      3: ['Data Structures', 'Discrete Structures', 'Digital Electronics', 'OOP with Java', 'Computer Architecture'],
      4: ['Algorithms', 'DBMS', 'Operating Systems', 'Data Communication', 'Automata Theory'],
      5: ['Computer Networks', 'Software Engineering', 'Web Engineering', 'Microprocessors', 'Statistics'],
      6: ['Information Security', 'Mobile Computing', 'Computer Graphics', 'Data Warehousing', 'Elective-I'],
      7: ['Cloud Computing', 'Machine Learning', 'Network Security', 'Project-I', 'Elective-II'],
      8: ['IoT', 'Big Data', 'Project-II', 'Elective-III', 'Industrial Training'],
    },
    'btech-ai-ml': {
      3: ['Data Structures', 'Discrete Mathematics', 'Python for AI', 'Digital Logic Design', 'Probability & Statistics'],
      4: ['Algorithms', 'Database Systems', 'Operating Systems', 'Foundations of AI', 'Linear Algebra'],
      5: ['Machine Learning', 'Computer Networks', 'Data Mining', 'Neural Networks', 'Optimization Techniques'],
      6: ['Deep Learning', 'Natural Language Processing', 'Computer Vision', 'Reinforcement Learning', 'Elective-I'],
      7: ['Generative AI', 'Big Data Analytics', 'AI Ethics', 'Project-I', 'Elective-II'],
      8: ['MLOps', 'Edge AI', 'Project-II', 'Elective-III', 'Industrial Training'],
    },
    'btech-ece': {
      3: ['Network Analysis', 'Electronic Devices & Circuits', 'Signals & Systems', 'Digital Electronics', 'Engineering Mathematics-III'],
      4: ['Analog Communication', 'Microprocessors', 'Control Systems', 'Electromagnetic Field Theory', 'Linear Integrated Circuits'],
      5: ['Digital Communication', 'Digital Signal Processing', 'Antenna & Wave Propagation', 'VLSI Design', 'Microcontrollers'],
      6: ['Microwave Engineering', 'Optical Communication', 'Embedded Systems', 'Information Theory & Coding', 'Elective-I'],
      7: ['Wireless Communication', 'Satellite Communication', 'CMOS Design', 'Project-I', 'Elective-II'],
      8: ['Mobile Communication', 'Project-II', 'Elective-III', 'Industrial Training', 'Seminar'],
    },
    'btech-ee': {
      3: ['Circuit Analysis', 'Electrical Machines-I', 'Electromagnetic Fields', 'Analog Electronics', 'Engineering Mathematics-III'],
      4: ['Electrical Machines-II', 'Power Systems-I', 'Control Systems', 'Digital Electronics', 'Measurements & Instrumentation'],
      5: ['Power Systems-II', 'Power Electronics', 'Microprocessors', 'Signals & Systems', 'Electrical Drives'],
      6: ['Switchgear & Protection', 'Digital Signal Processing', 'Renewable Energy Systems', 'High Voltage Engineering', 'Elective-I'],
      7: ['Power System Operation & Control', 'Industrial Drives', 'Project-I', 'Elective-II', 'Elective-III'],
      8: ['Smart Grid', 'Project-II', 'Industrial Training', 'Elective-IV', 'Seminar'],
    },
    'btech-me': {
      3: ['Thermodynamics', 'Strength of Materials', 'Manufacturing Processes', 'Engineering Mechanics', 'Engineering Mathematics-III'],
      4: ['Fluid Mechanics', 'Theory of Machines-I', 'Material Science', 'Machine Drawing', 'Applied Thermodynamics'],
      5: ['Heat & Mass Transfer', 'Theory of Machines-II', 'Machine Design-I', 'Internal Combustion Engines', 'Industrial Engineering'],
      6: ['Refrigeration & Air Conditioning', 'Machine Design-II', 'Manufacturing Technology', 'Dynamics of Machines', 'Elective-I'],
      7: ['Automobile Engineering', 'CAD/CAM', 'Power Plant Engineering', 'Project-I', 'Elective-II'],
      8: ['Mechatronics', 'Operations Management', 'Project-II', 'Industrial Training', 'Elective-III'],
    },
    'btech-civil': {
      3: ['Strength of Materials', 'Surveying-I', 'Fluid Mechanics', 'Building Materials & Construction', 'Engineering Mathematics-III'],
      4: ['Structural Analysis-I', 'Surveying-II', 'Concrete Technology', 'Soil Mechanics', 'Hydraulics'],
      5: ['Structural Analysis-II', 'Design of RC Structures', 'Geotechnical Engineering', 'Transportation Engineering-I', 'Water Resources Engineering'],
      6: ['Design of Steel Structures', 'Environmental Engineering-I', 'Transportation Engineering-II', 'Foundation Engineering', 'Elective-I'],
      7: ['Environmental Engineering-II', 'Estimation & Costing', 'Construction Management', 'Project-I', 'Elective-II'],
      8: ['Earthquake Engineering', 'Project-II', 'Industrial Training', 'Elective-III', 'Seminar'],
    },
  };
  return { ...btechCommon, ...(map[branch] || {}) };
};

// MBA (4 sem)
const mba = {
  1: ['Management Principles & Organizational Behaviour', 'Managerial Economics', 'Accounting for Managers', 'Quantitative Techniques', 'Business Communication', 'Marketing Management'],
  2: ['Financial Management', 'Human Resource Management', 'Operations Management', 'Business Research Methods', 'Management Information Systems', 'Business Environment'],
  3: ['Strategic Management', 'Marketing Specialization-I', 'Finance Specialization-I', 'HR Specialization-I', 'Operations Research', 'Entrepreneurship Development'],
  4: ['Corporate Governance & Ethics', 'Marketing Specialization-II', 'Finance Specialization-II', 'International Business', 'Project Work / Dissertation', 'Strategic Leadership'],
};

// MCA (4 sem)
const mca = {
  1: ['Advanced Data Structures', 'Computer Organization & Architecture', 'Discrete Mathematics', 'Object Oriented Programming', 'Operating Systems'],
  2: ['Design & Analysis of Algorithms', 'Database Management Systems', 'Advanced Java Programming', 'Computer Networks', 'Software Engineering'],
  3: ['Machine Learning', 'Web Technologies', 'Data Mining & Warehousing', 'Cloud Computing', 'Information Security'],
  4: ['Big Data Analytics', 'Mobile Application Development', 'Project Work / Dissertation', 'Artificial Intelligence', 'DevOps & MLOps'],
};

// MCom (4 sem)
const mcom = {
  1: ['Managerial Economics', 'Financial Management', 'Statistical Analysis', 'Organizational Behaviour', 'Accounting Theory & Practice'],
  2: ['Corporate Tax Planning', 'Marketing Management', 'Business Environment', 'Cost & Management Accounting', 'Research Methodology'],
  3: ['Security Analysis & Portfolio Management', 'International Business', 'Advanced Auditing', 'Financial Markets', 'Elective-I'],
  4: ['Strategic Financial Management', 'Indirect Taxation (GST)', 'Project Work / Dissertation', 'Entrepreneurship', 'Elective-II'],
};

// MA (general by stream) — 4 sem
const maStream = (core) => ({
  1: [`${core} Paper-I`, `${core} Paper-II`, 'Research Methodology', `${core} Paper-III`, `${core} Paper-IV`],
  2: [`${core} Paper-V`, `${core} Paper-VI`, `${core} Paper-VII`, `${core} Paper-VIII`, 'Computer Applications'],
  3: [`Advanced ${core}-I`, `Advanced ${core}-II`, `${core} Elective-I`, `${core} Elective-II`, 'Seminar'],
  4: [`Advanced ${core}-III`, `${core} Elective-III`, `${core} Elective-IV`, 'Dissertation / Project', 'Viva Voce'],
});

// MSc (general by stream) — 4 sem
const mscStream = (core) => ({
  1: [`${core}-I`, `${core}-II`, `${core} Lab-I`, 'Mathematical Methods', 'Research Methodology'],
  2: [`${core}-III`, `${core}-IV`, `${core} Lab-II`, 'Computational Techniques', 'Elective-I'],
  3: [`Advanced ${core}-I`, `Advanced ${core}-II`, `${core} Lab-III`, 'Elective-II', 'Seminar'],
  4: [`Advanced ${core}-III`, `${core} Special Paper`, 'Dissertation / Project', 'Elective-III', 'Viva Voce'],
});

// MTech CSE (4 sem)
const mtechCse = {
  1: ['Advanced Algorithms', 'Advanced Computer Architecture', 'Mathematical Foundations of CS', 'Advanced Database Systems', 'Elective-I'],
  2: ['Machine Learning', 'Distributed Systems', 'Advanced Computer Networks', 'Cloud Computing', 'Elective-II'],
  3: ['Research Seminar', 'Dissertation Phase-I', 'Elective-III', 'Elective-IV', 'Deep Learning'],
  4: ['Dissertation Phase-II', 'Viva Voce', 'Research Publication', 'Elective-V', 'Project Defense'],
};

// Law: LLB (6 sem), LLM (4 sem), integrated BA/BBA-LLB (10 sem)
const llb = {
  1: ['Legal Method', 'Law of Contract-I', 'Law of Torts', 'Constitutional Law-I', 'Family Law-I'],
  2: ['Law of Contract-II', 'Constitutional Law-II', 'Family Law-II', 'Law of Crimes (IPC)', 'Professional Ethics'],
  3: ['Property Law', 'Administrative Law', 'Company Law', 'Public International Law', 'Jurisprudence'],
  4: ['Labour Law', 'Civil Procedure Code', 'Criminal Procedure Code', 'Environmental Law', 'Law of Evidence'],
  5: ['Land Laws', 'Interpretation of Statutes', 'Intellectual Property Law', 'Banking Law', 'Clinical Course-I'],
  6: ['Human Rights Law', 'Taxation Law', 'Arbitration & ADR', 'Clinical Course-II', 'Moot Court & Internship'],
};
const llm = {
  1: ['Constitutionalism', 'Legal Research Methodology', 'Law & Social Transformation', 'Comparative Public Law', 'Judicial Process'],
  2: ['Specialization Paper-I', 'Specialization Paper-II', 'Human Rights & International Law', 'Intellectual Property Rights', 'Elective-I'],
  3: ['Specialization Paper-III', 'Specialization Paper-IV', 'Dissertation Phase-I', 'Elective-II', 'Seminar'],
  4: ['Specialization Paper-V', 'Dissertation Phase-II', 'Viva Voce', 'Elective-III', 'Research Publication'],
};
// Integrated 5-year law: years 1-2 (sem 1-4) foundation arts/management + law from sem 3.
const integratedLaw = (foundation) => ({
  1: [...(foundation[1] || []).slice(0, 3), 'Legal Method', 'Law of Torts'],
  2: [...(foundation[2] || []).slice(0, 3), 'Law of Contract-I', 'Political Science / Management-I'],
  3: ['Law of Contract-II', 'Constitutional Law-I', 'Family Law-I', 'Economics / Management-II', 'Sociology / Marketing'],
  4: ['Constitutional Law-II', 'Family Law-II', 'Law of Crimes (IPC)', 'History / Finance', 'Jurisprudence'],
  5: ['Property Law', 'Administrative Law', 'Company Law', 'Public International Law', 'Labour Law'],
  6: ['Civil Procedure Code', 'Criminal Procedure Code', 'Law of Evidence', 'Environmental Law', 'Intellectual Property Law'],
  7: ['Land Laws', 'Interpretation of Statutes', 'Banking & Insurance Law', 'Human Rights Law', 'Clinical Course-I'],
  8: ['Taxation Law', 'Arbitration & ADR', 'Competition Law', 'Clinical Course-II', 'Elective-I'],
  9: ['Drafting, Pleading & Conveyancing', 'Professional Ethics', 'Moot Court', 'Elective-II', 'Seminar'],
  10: ['Internship / Dissertation', 'Cyber Law', 'International Trade Law', 'Elective-III', 'Viva Voce'],
});

// Education
const bed = {
  1: ['Childhood & Growing Up', 'Contemporary India & Education', 'Learning & Teaching', 'Language across the Curriculum', 'Understanding Disciplines & Subjects'],
  2: ['Knowledge & Curriculum', 'Assessment for Learning', 'Pedagogy of School Subject-I', 'Pedagogy of School Subject-II', 'School Internship'],
  3: ['Gender, School & Society', 'Inclusive Education', 'Educational Technology & ICT', 'Optional Course-I', 'School Internship-II'],
  4: ['Creating an Inclusive School', 'Health, Yoga & Physical Education', 'Understanding the Self', 'Optional Course-II', 'Final Practicum'],
};
const med = {
  1: ['Philosophy of Education', 'Sociology of Education', 'Psychology of Learning', 'Educational Research-I', 'History of Education'],
  2: ['Curriculum Studies', 'Educational Measurement & Evaluation', 'Educational Research-II', 'Teacher Education', 'Elective-I'],
  3: ['Educational Technology', 'Comparative Education', 'Dissertation Phase-I', 'Elective-II', 'Seminar'],
  4: ['Educational Administration & Management', 'Guidance & Counselling', 'Dissertation Phase-II', 'Elective-III', 'Viva Voce'],
};
const bped = {
  1: ['History & Foundation of Physical Education', 'Anatomy & Physiology', 'Health Education', 'Track & Field-I', 'Gymnastics'],
  2: ['Educational Psychology in PE', 'Kinesiology & Biomechanics', 'Sports Training', 'Track & Field-II', 'Yoga'],
  3: ['Sports Medicine', 'Sports Management', 'Officiating & Coaching', 'Games Specialization-I', 'Recreation'],
  4: ['Research Methods in PE', 'Test & Measurement in PE', 'Sports Psychology', 'Games Specialization-II', 'Internship'],
};
const mped = {
  1: ['Scientific Principles of Sports Training', 'Exercise Physiology', 'Research Methodology in PE', 'Sports Management', 'Athletics-I'],
  2: ['Sports Biomechanics', 'Sports Psychology', 'Statistics in Physical Education', 'Sports Medicine', 'Game Specialization-I'],
  3: ['Test, Measurement & Evaluation', 'Yogic Sciences', 'Dissertation Phase-I', 'Game Specialization-II', 'Seminar'],
  4: ['Sports Nutrition', 'Curriculum Design in PE', 'Dissertation Phase-II', 'Coaching Specialization', 'Viva Voce'],
};

// Pharmacy (8 sem)
const bpharm = {
  1: ['Human Anatomy & Physiology-I', 'Pharmaceutical Analysis-I', 'Pharmaceutics-I', 'Pharmaceutical Inorganic Chemistry', 'Communication Skills'],
  2: ['Human Anatomy & Physiology-II', 'Pharmaceutical Organic Chemistry-I', 'Biochemistry', 'Pathophysiology', 'Computer Applications in Pharmacy'],
  3: ['Pharmaceutical Organic Chemistry-II', 'Physical Pharmaceutics-I', 'Pharmaceutical Microbiology', 'Pharmaceutical Engineering', 'Pharmacognosy-I'],
  4: ['Pharmaceutical Organic Chemistry-III', 'Medicinal Chemistry-I', 'Physical Pharmaceutics-II', 'Pharmacology-I', 'Pharmacognosy-II'],
  5: ['Medicinal Chemistry-II', 'Industrial Pharmacy-I', 'Pharmacology-II', 'Pharmaceutical Jurisprudence', 'Pharmacognosy-III'],
  6: ['Medicinal Chemistry-III', 'Pharmacology-III', 'Herbal Drug Technology', 'Biopharmaceutics & Pharmacokinetics', 'Pharmaceutical Biotechnology'],
  7: ['Industrial Pharmacy-II', 'Pharmacy Practice', 'Novel Drug Delivery Systems', 'Instrumental Methods of Analysis', 'Elective-I'],
  8: ['Biostatistics & Research Methodology', 'Social & Preventive Pharmacy', 'Pharmacovigilance', 'Project Work', 'Quality Control & Quality Assurance'],
};
const mpharm = {
  1: ['Modern Pharmaceutical Analytical Techniques', 'Drug Delivery Systems', 'Pharmaceutical Formulation Development', 'Research Methodology & Biostatistics', 'Elective-I'],
  2: ['Molecular Pharmaceutics', 'Advanced Pharmaceutical Analysis', 'Regulatory Affairs', 'Cosmetic & Herbal Technology', 'Elective-II'],
  3: ['Research Project Phase-I', 'Seminar', 'Journal Club', 'Discussion / Final Year', 'Elective-III'],
  4: ['Research Project Phase-II', 'Dissertation', 'Viva Voce', 'Research Publication', 'Elective-IV'],
};

// Hotel Management (8 sem) & Tourism (6 sem)
const bhmct = {
  1: ['Foundation of Food Production-I', 'Foundation of Food & Beverage Service-I', 'Front Office Operations-I', 'Housekeeping Operations-I', 'Hotel Engineering'],
  2: ['Foundation of Food Production-II', 'Food & Beverage Service-II', 'Front Office-II', 'Housekeeping-II', 'Nutrition & Food Science'],
  3: ['Food Production-III', 'Food & Beverage Service-III', 'Accommodation Management', 'Hotel Accounting', 'Communication Skills'],
  4: ['Quantity Food Production', 'Beverage Management', 'Food Safety & Hygiene', 'Hotel French', 'Industrial Training'],
  5: ['Advanced Food Production', 'Bar & Beverage Operations', 'Hotel Marketing', 'Human Resource Management', 'Facility Planning'],
  6: ['Larder & Bakery', 'Food & Beverage Controls', 'Financial Management', 'Tourism Management', 'Elective-I'],
  7: ['Hotel Operations Management', 'Entrepreneurship in Hospitality', 'Research Project-I', 'Strategic Management', 'Elective-II'],
  8: ['Hospitality Law', 'Event Management', 'Research Project-II', 'Industrial Exposure Training', 'Elective-III'],
};
const mhmct = {
  1: ['Principles of Management', 'Advanced Food Production', 'Accommodation Management', 'Hospitality Marketing', 'Research Methodology'],
  2: ['Food & Beverage Management', 'Financial Management in Hospitality', 'Human Resource Management', 'Tourism & Travel Management', 'Elective-I'],
  3: ['Strategic Hospitality Management', 'Facility Planning & Design', 'Dissertation Phase-I', 'Elective-II', 'Seminar'],
  4: ['Hospitality Law & Ethics', 'Entrepreneurship Development', 'Dissertation Phase-II', 'Elective-III', 'Viva Voce'],
};
const bttm = {
  1: ['Foundation of Tourism', 'Indian History & Culture', 'Tourism Geography', 'Communication Skills', 'Computer Applications'],
  2: ['Tourism Products of India', 'Travel Agency & Tour Operations', 'Tourism Marketing', 'Environmental Studies', 'Hospitality Management'],
  3: ['Tour Guiding & Escorting', 'Airline & Airport Management', 'Tourism Economics', 'Cultural Tourism', 'Event Management'],
  4: ['Travel Management', 'Eco & Sustainable Tourism', 'Tourism Policy & Planning', 'Foreign Language', 'Industrial Training'],
  5: ['International Tourism', 'Tourism Entrepreneurship', 'Destination Management', 'Human Resource Management', 'Elective-I'],
  6: ['Tourism Research', 'Adventure & Medical Tourism', 'E-Tourism', 'Project Work', 'Elective-II'],
};
const mttm = {
  1: ['Principles of Tourism Management', 'Tourism Products & Resources', 'Travel Agency & Tour Operations Management', 'Research Methodology', 'Tourism Marketing'],
  2: ['Tourism Planning & Development', 'Airline & Cargo Management', 'Hospitality & Event Management', 'Financial Management in Tourism', 'Elective-I'],
  3: ['International Tourism Management', 'Sustainable Tourism', 'Dissertation Phase-I', 'Elective-II', 'Seminar'],
  4: ['Tourism Entrepreneurship', 'Destination Branding', 'Dissertation Phase-II', 'Elective-III', 'Viva Voce'],
};
// Fine Arts (8 sem)
const bfa = {
  1: ['Fundamentals of Visual Arts', 'Drawing-I', 'History of Indian Art-I', 'Colour Theory', 'Design Basics'],
  2: ['Drawing-II', 'Painting-I', 'History of Indian Art-II', 'Sculpture Basics', 'Computer Graphics'],
  3: ['Painting-II', 'Applied Art-I', 'History of Western Art-I', 'Printmaking-I', 'Photography'],
  4: ['Painting-III', 'Applied Art-II', 'History of Western Art-II', 'Printmaking-II', 'Digital Art'],
  5: ['Advanced Painting-I', 'Mural Design', 'Aesthetics-I', 'Portfolio Development', 'Elective-I'],
  6: ['Advanced Painting-II', 'Illustration', 'Aesthetics-II', 'Art Appreciation', 'Elective-II'],
  7: ['Studio Practice-I', 'Contemporary Art', 'Project-I', 'Exhibition Design', 'Elective-III'],
  8: ['Studio Practice-II', 'Art Criticism', 'Project-II', 'Final Display', 'Portfolio & Viva'],
};

// ---- Map every course slug to its semester->subjects ---------------------

const COURSES = {
  bca, bba, bcom,
  'bcom-hons': bcom,
  ba,
  'ba-english': maEnglishLike('English Literature'),
  'ba-hindi': maEnglishLike('Hindi Literature'),
  'ba-history': maEnglishLike('History'),
  'ba-political-science': maEnglishLike('Political Science'),
  'ba-economics': maEnglishLike('Economics'),
  'bsc-cs': bscCs,
  'bsc-physics': bscScience('Physics'),
  'bsc-chemistry': bscScience('Chemistry'),
  'bsc-maths': bscScience('Mathematics'),
  'bsc-biotech': bscScience('Biotechnology'),
  'bsc-botany': bscScience('Botany'),
  'bsc-zoology': bscScience('Zoology'),
  'btech-cse': btech('btech-cse'),
  'btech-it': btech('btech-it'),
  'btech-ai-ml': btech('btech-ai-ml'),
  'btech-ece': btech('btech-ece'),
  'btech-ee': btech('btech-ee'),
  'btech-me': btech('btech-me'),
  'btech-civil': btech('btech-civil'),
  bpharm,
  bhmct,
  bttm,
  bfa,
  'ba-llb': integratedLaw(ba),
  'bba-llb': integratedLaw(bba),
  llb,
  bed,
  bped,
  mba, mca, mcom,
  'ma-english': maStream('English Literature'),
  'ma-hindi': maStream('Hindi Literature'),
  'ma-history': maStream('History'),
  'ma-political-science': maStream('Political Science'),
  'ma-economics': maStream('Economics'),
  'msc-cs': mscStream('Computer Science'),
  'msc-physics': mscStream('Physics'),
  'msc-chemistry': mscStream('Chemistry'),
  'msc-maths': mscStream('Mathematics'),
  'msc-biotech': mscStream('Biotechnology'),
  'mtech-cse': mtechCse,
  mpharm,
  llm,
  med,
  mped,
  mttm,
  mhmct,
};

// BA subject-stream UG (6 sem) — first 3 sems use general arts, deeper later.
function maEnglishLike(core) {
  return {
    1: [`${core}-I`, 'English Communication', 'Environmental Studies', 'Elective-I', 'Elective-II'],
    2: [`${core}-II`, 'Hindi/MIL', 'Information Technology', 'Elective-III', 'Elective-IV'],
    3: [`${core}-III`, `${core} Special-I`, 'Research Skills', 'Elective-V', 'Elective-VI'],
    4: [`${core}-IV`, `${core} Special-II`, 'Statistical Methods', 'Elective-VII', 'Elective-VIII'],
    5: [`Advanced ${core}-I`, `${core} Optional-I`, 'Project-I', 'Elective-IX', 'Skill Course-I'],
    6: [`Advanced ${core}-II`, `${core} Optional-II`, 'Project-II', 'Elective-X', 'Skill Course-II'],
  };
}

// ---- Emit SQL ------------------------------------------------------------

import { researched } from './researchedSubjects.mjs';

const esc = (s) => s.replace(/'/g, "''");
let sql = `-- ============================================================
-- MDU Papers — Subjects seed for ALL courses (semester-wise)
-- Researched real MDU data for 10 major courses (BCA, BBA, BCom, BA,
-- BSc-CS, B.Tech CSE, MBA, MCA, MA English, MCom). Others use standard
-- curricula as a starting point. Edit/add/remove via the admin panel.
-- Safe to re-run: ON CONFLICT (course_id, semester, slug) DO NOTHING.
-- Run AFTER seed-courses.sql.
-- ============================================================

`;

// Merge researched data over the generic COURSES map (researched wins).
for (const [slug, sems] of Object.entries(researched)) {
  const converted = {};
  for (const [sem, rows] of Object.entries(sems)) {
    converted[sem] = rows.map((r) => (Array.isArray(r) ? r[0] : r));
  }
  COURSES[slug] = converted;
}

let total = 0;
for (const [slug, sems] of Object.entries(COURSES)) {
  sql += `-- ${slug}\n`;
  for (const [sem, subjects] of Object.entries(sems)) {
    for (const name of subjects) {
      const subjectSlug = slugify(name);
      sql += `INSERT INTO subjects (course_id, semester, name, slug) SELECT id, ${sem}, '${esc(name)}', '${subjectSlug}' FROM courses WHERE slug='${slug}' ON CONFLICT (course_id, semester, slug) DO NOTHING;\n`;
      total++;
    }
  }
  sql += '\n';
}

writeFileSync('supabase/seed-subjects.sql', sql);
console.log(`Generated supabase/seed-subjects.sql with ${total} subject inserts across ${Object.keys(COURSES).length} courses.`);
