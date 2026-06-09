# Import all models so SQLAlchemy registers them before create_all()
from .user import User, UserRole
from .auth import BlacklistedToken
from .course import SkillCategory, Course, UserCourseProgress, Lesson, UserLessonProgress, LearningResource
from .wellness import CounsellingAvailability, CounsellingSession
from .counselling import MentorProfile, CounsellingNotification
from .badge import Badge, UserBadge
from .reward import RewardRule, RewardTask, RewardTransaction, UserStreak, UserMilestone
from .event import Event, EventParticipant, EventQuiz, EventSelection, EventSlot, EventType, EventStatus, SelectionMethod, QuizMapping
from .quiz import Quiz, Question, QuizAttempt, DailyChallenge, QuizDifficulty
from .safety import SafetyAwarenessQuestion, UserSafetyAnswer
from .emergency import EmergencyContact
from .chat import ChatMessage
from .notification import AdminNotification
from .calendar import StudentReminder
from .creator_post import CreatorPost
from .donation import Donation, DonationStatus
from .payment import Payment, PaymentStatus, PaymentPurpose
from .feedback import Feedback, FeedbackCategory, FeedbackStatus
from .discount import DiscountCode, DiscountType
from .reaction import Reaction, ReactionType, TargetType
from .comment import Comment
from .review import Review, ReviewStatus, ReviewTargetType
