import 'package:flutter/material.dart';

class RaidQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final int baseDamage;

  const RaidQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.baseDamage = 35,
  });
}

class DungeonGateModel {
  final String gateId;
  final String name;
  final String rank; // 'E', 'D', 'C', 'B', 'A', 'S'
  final String bossName;
  final String bossEmoji;
  final int maxHp;
  int currentHp;
  final int xpReward;
  final String relicDrop;
  final String relicId;
  final String subjectTheme;
  final List<RaidQuestion> questions;

  DungeonGateModel({
    required this.gateId,
    required this.name,
    required this.rank,
    required this.bossName,
    required this.bossEmoji,
    required this.maxHp,
    required this.currentHp,
    required this.xpReward,
    required this.relicDrop,
    required this.subjectTheme,
    this.relicId = '',
    this.questions = const [],
  });

  Color get rankColor {
    switch (rank) {
      case 'S':
        return const Color(0xFFFFD700);
      case 'A':
        return const Color(0xFFEF4444);
      case 'B':
        return const Color(0xFFA855F7);
      case 'C':
        return const Color(0xFF38BDF8);
      case 'D':
        return const Color(0xFF22C55E);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  static List<DungeonGateModel> getDefaultGates() {
    return [
      DungeonGateModel(
        gateId: 'gate_math_golem',
        name: 'C-Rank Gate: Math Labyrinth',
        rank: 'C',
        bossName: 'Calculus Golem',
        bossEmoji: '🗿',
        maxHp: 300,
        currentHp: 210,
        xpReward: 120,
        relicDrop: 'Golem Core of Precision',
        relicId: 'golem_core',
        subjectTheme: 'Mathematics',
        questions: const [
          RaidQuestion(
            question: 'What is the derivative of f(x) = x² + 3x?',
            options: ['2x + 3', 'x² + 3', '2x', '3x'],
            correctIndex: 0,
            explanation: "Power rule: d/dx(x^n) = n*x^(n-1). d/dx(x²)=2x and d/dx(3x)=3.",
            baseDamage: 40,
          ),
          RaidQuestion(
            question: 'If sin(θ) = 1/2 for 0 ≤ θ ≤ π/2, what is θ?',
            options: ['π/6 (30°)', 'π/4 (45°)', 'π/3 (60°)', 'π/2 (90°)'],
            correctIndex: 0,
            explanation: 'sin(30°) = sin(π/6) = 1/2.',
            baseDamage: 35,
          ),
          RaidQuestion(
            question: 'What is the determinant of matrix [[2, 1], [3, 4]]?',
            options: ['5', '8', '11', '3'],
            correctIndex: 0,
            explanation: 'det = (2 * 4) - (1 * 3) = 8 - 3 = 5.',
            baseDamage: 45,
          ),
          RaidQuestion(
            question: 'Solve for x: log₂(x) = 5',
            options: ['32', '25', '10', '64'],
            correctIndex: 0,
            explanation: 'x = 2^5 = 32.',
            baseDamage: 40,
          ),
        ],
      ),
      DungeonGateModel(
        gateId: 'gate_physics_titan',
        name: 'B-Rank Red Gate: Magnetic Vortex',
        rank: 'B',
        bossName: 'Physics Monarch',
        bossEmoji: '⚡',
        maxHp: 500,
        currentHp: 480,
        xpReward: 200,
        relicDrop: "Ruler's Vector Crest",
        relicId: 'rulers_crest',
        subjectTheme: 'Physics',
        questions: const [
          RaidQuestion(
            question: 'What is the SI unit of magnetic flux density?',
            options: ['Tesla (T)', 'Weber (Wb)', 'Henry (H)', 'Volt (V)'],
            correctIndex: 0,
            explanation: 'Tesla is the SI unit of magnetic flux density (B).',
            baseDamage: 50,
          ),
          RaidQuestion(
            question: 'According to Faraday\'s Law, induced EMF is proportional to:',
            options: [
              'Rate of change of magnetic flux',
              'Constant electric charge',
              'Resistance of the coil only',
              'Mass of the conductor',
            ],
            correctIndex: 0,
            explanation: 'ε = -dΦB / dt: induced EMF equals rate of change of magnetic flux.',
            baseDamage: 55,
          ),
          RaidQuestion(
            question: 'If the velocity of an object doubles, its kinetic energy increases by:',
            options: ['4x (Quadruples)', '2x (Doubles)', '8x', 'Remains identical'],
            correctIndex: 0,
            explanation: 'KE = 1/2 m v². If v -> 2v, KE -> 4 * KE.',
            baseDamage: 45,
          ),
          RaidQuestion(
            question: 'What is the escape velocity formula from a celestial body of mass M and radius R?',
            options: ['√(2GM/R)', '√(GM/R)', '2GM/R²', 'GM/R²'],
            correctIndex: 0,
            explanation: 'v_esc = sqrt(2GM / R).',
            baseDamage: 60,
          ),
        ],
      ),
      DungeonGateModel(
        gateId: 'gate_bio_chimera',
        name: 'A-Rank Gate: Cell Mutation',
        rank: 'A',
        bossName: 'Organic Chimera',
        bossEmoji: '🐉',
        maxHp: 800,
        currentHp: 800,
        xpReward: 350,
        relicDrop: 'Eternal Helix Artifact',
        relicId: 'eternal_helix',
        subjectTheme: 'Biology',
        questions: const [
          RaidQuestion(
            question: 'Which organelle is responsible for ATP synthesis in eukaryotic cells?',
            options: ['Mitochondria', 'Golgi Apparatus', 'Endoplasmic Reticulum', 'Lysosome'],
            correctIndex: 0,
            explanation: 'Mitochondria generate the majority of cellular adenosine triphosphate (ATP).',
            baseDamage: 60,
          ),
          RaidQuestion(
            question: 'During DNA replication, which enzyme unwinds the double helix?',
            options: ['DNA Helicase', 'DNA Polymerase', 'DNA Ligase', 'RNA Primase'],
            correctIndex: 0,
            explanation: 'Helicase breaks hydrogen bonds between nucleotide base pairs.',
            baseDamage: 65,
          ),
          RaidQuestion(
            question: 'In which phase of mitosis do sister chromatids pull apart to opposite poles?',
            options: ['Anaphase', 'Prophase', 'Metaphase', 'Telophase'],
            correctIndex: 0,
            explanation: 'During anaphase, spindle fibers pull sister chromatids to opposite poles.',
            baseDamage: 70,
          ),
          RaidQuestion(
            question: 'What is the universal start codon in mRNA translation?',
            options: ['AUG (Methionine)', 'UAA (Ochre)', 'UAG (Amber)', 'UGA (Opal)'],
            correctIndex: 0,
            explanation: 'AUG codes for Methionine and marks the translation initiation site.',
            baseDamage: 75,
          ),
        ],
      ),
    ];
  }
}
