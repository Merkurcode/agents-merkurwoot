/* global axios */
import ApiClient from './ApiClient';

class LeadFollowUpSequencesAPI extends ApiClient {
  constructor() {
    super('copilot_sequences', { accountScoped: true });
  }

  activate(sequenceId) {
    return axios.post(`${this.url}/${sequenceId}/activate`);
  }

  deactivate(sequenceId) {
    return axios.post(`${this.url}/${sequenceId}/deactivate`);
  }

  getAvailableTemplates(inboxId) {
    return axios.get(`${this.url}/available_templates`, {
      params: { inbox_id: inboxId },
    });
  }

  previewEligible(params) {
    return axios.post(`${this.url}/preview_eligible`, params);
  }

  previewEligibleContacts(sourceConfig) {
    return axios.post(`${this.url}/preview_eligible_contacts`, {
      source_config: sourceConfig,
    });
  }

  getEnrolledConversations(sequenceId, params = {}) {
    return axios.get(`${this.url}/${sequenceId}/enrolled_conversations`, {
      params: params,
    });
  }

  cancelFollowUps(sequenceId, followUpIds) {
    return axios.post(`${this.url}/${sequenceId}/cancel_follow_ups`, {
      follow_up_ids: followUpIds,
    });
  }

  getEnrollmentTimeline(sequenceId, enrollmentId) {
    return axios.get(
      `${this.url}/${sequenceId}/enrollments/${enrollmentId}/timeline`
    );
  }

  submitEnrollmentResult(sequenceId, enrollmentId, values) {
    return axios.post(
      `${this.url}/${sequenceId}/enrollments/${enrollmentId}/result`,
      { values }
    );
  }

  cancelEnrollment(sequenceId, enrollmentId, { reason, values } = {}) {
    return axios.post(
      `${this.url}/${sequenceId}/enrollments/${enrollmentId}/cancel`,
      { reason, values }
    );
  }

  getResultIndicators(sequenceId) {
    return axios.get(`${this.url}/${sequenceId}/result_indicators`);
  }
}

export default new LeadFollowUpSequencesAPI();
