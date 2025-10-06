class Api::V1::Accounts::Contacts::SurveyAnswersController < Api::V1::Accounts::Contacts::BaseController
  def index
    @survey_answers = @contact.survey_answers
                              .includes(survey_question: [:survey, :survey_question_options], survey_question_option: [])
                              .order('survey_questions.survey_id DESC, survey_questions.position ASC')
  end
end
